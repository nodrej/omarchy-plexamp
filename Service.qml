import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "PlexampModel.js" as PlexampModel

// Headless half of the plugin: owns the MPRIS binding to Plexamp, keeps a
// smooth playback position, and exposes both a QML surface for the bar widget
// and an IPC target for keybindings.
//
// The shell mounts this once per session (it is loaded because the plugin id
// appears in shell.json), so the bar widget instance on every monitor talks to
// the same object and they can never disagree about what is playing.
Item {
  id: root

  // Injected by the shell host.
  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  // Mirrored from the bar widget's inline shell.json settings.
  property string launchCommand: "plexamp.desktop"
  property int seekStep: 10

  // Panel requests arrive here rather than in the widget: the service is the
  // single instance, so one IPC handler serves every monitor's widget instead
  // of four fighting over the same target. Mode is "toggle", "open", "close".
  signal panelRequested(string mode)

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: PlexampModel.pickPlayer(players)

  readonly property bool running: player !== null
  readonly property bool playing: !!(player && player.isPlaying)
  readonly property bool hasTrack: PlexampModel.hasTrack(player)

  readonly property string title: player && player.trackTitle ? String(player.trackTitle) : ""
  readonly property string artist: PlexampModel.artistOf(player)
  readonly property string album: player && player.trackAlbum ? String(player.trackAlbum) : ""
  readonly property string artUrl: player && player.trackArtUrl ? String(player.trackArtUrl) : ""

  readonly property bool canSeek: !!(player && player.canSeek && player.positionSupported)
  readonly property real length: player && player.lengthSupported && isFinite(player.length) ? player.length : 0
  readonly property bool canControl: !!(player && player.canControl)
  readonly property bool canGoNext: !!(player && player.canGoNext)
  readonly property bool canGoPrevious: !!(player && player.canGoPrevious)
  readonly property bool canTogglePlaying: !!(player && (player.canTogglePlaying || player.canPlay || player.canPause))

  readonly property bool shuffleSupported: !!(player && player.shuffleSupported)
  readonly property bool shuffle: !!(player && player.shuffle)
  readonly property bool loopSupported: !!(player && player.loopSupported)
  readonly property int loopState: player ? player.loopState : MprisLoopState.None
  readonly property bool volumeSupported: !!(player && player.volumeSupported)
  readonly property real volume: player && isFinite(player.volume) ? player.volume : 0

  // Displayed playback position. MPRIS only reports position on demand, so the
  // value is interpolated from the last known sample and re-synced on a slow
  // timer; the panel's seek bar therefore advances smoothly instead of
  // stepping once a second.
  property real position: 0
  property real basePosition: 0
  property double baseAt: 0

  readonly property real progress: PlexampModel.progressFraction(position, length)
  readonly property string positionLabel: PlexampModel.formatTime(position)
  readonly property string lengthLabel: length > 0 ? PlexampModel.formatTime(length) : "--:--"
  readonly property string trackSignature: PlexampModel.trackSignature(player)

  function resyncPosition() {
    if (!player || !player.positionSupported) {
      basePosition = 0
      baseAt = Date.now()
      position = 0
      return
    }
    var sampled = Number(player.position)
    basePosition = isFinite(sampled) && sampled >= 0 ? sampled : 0
    baseAt = Date.now()
    updatePosition()
  }

  function updatePosition() {
    if (!player) {
      position = 0
      return
    }
    var elapsed = playing ? (Date.now() - baseAt) / 1000 : 0
    var next = basePosition + elapsed
    position = length > 0 ? PlexampModel.clamp(next, 0, length) : Math.max(0, next)
  }

  // ------------------------------------------------------------- actions

  function play() {
    if (!player) return false
    if (player.canPlay) { player.play(); return true }
    if (player.canTogglePlaying && !player.isPlaying) { player.togglePlaying(); return true }
    return false
  }

  function pause() {
    if (!player) return false
    if (player.canPause) { player.pause(); return true }
    if (player.canTogglePlaying && player.isPlaying) { player.togglePlaying(); return true }
    return false
  }

  function playPause() {
    if (!player) return false
    return player.isPlaying ? pause() : play()
  }

  function next() {
    if (!player || !player.canGoNext) return false
    player.next()
    return true
  }

  function previous() {
    if (!player || !player.canGoPrevious) return false
    player.previous()
    return true
  }

  function seekTo(seconds) {
    if (!canSeek) return false
    var target = PlexampModel.clamp(seconds, 0, length > 0 ? length : seconds)
    player.position = target
    basePosition = target
    baseAt = Date.now()
    position = target
    return true
  }

  function seekBy(delta) {
    if (!canSeek) return false
    return seekTo(position + delta)
  }

  function seekToFraction(fraction) {
    if (!canSeek || length <= 0) return false
    return seekTo(PlexampModel.clamp(fraction, 0, 1) * length)
  }

  function setVolume(value) {
    if (!player || !player.volumeSupported) return false
    player.volume = PlexampModel.clamp(value, 0, 1)
    return true
  }

  function nudgeVolume(delta) {
    if (!player || !player.volumeSupported) return false
    return setVolume(volume + delta)
  }

  function toggleShuffle() {
    if (!player || !player.shuffleSupported) return false
    player.shuffle = !player.shuffle
    return true
  }

  // None -> Playlist -> Track -> None, the order every music player uses: turn
  // repeat on for the queue first, then narrow it to the current track.
  function cycleLoop() {
    if (!player || !player.loopSupported) return false
    if (player.loopState === MprisLoopState.None) player.loopState = MprisLoopState.Playlist
    else if (player.loopState === MprisLoopState.Playlist) player.loopState = MprisLoopState.Track
    else player.loopState = MprisLoopState.None
    return true
  }

  function launch() {
    var command = launchCommand && launchCommand.length > 0 ? launchCommand : "plexamp.desktop"
    // omarchy-launch-or-focus raises an existing window when there is one, so
    // this stays correct even if MPRIS has not come up yet.
    Quickshell.execDetached(["omarchy-launch-or-focus", "plexamp", "uwsm-app -- " + command])
    return true
  }

  function raiseOrLaunch() {
    if (player && player.canRaise) {
      player.raise()
      return true
    }
    return launch()
  }

  // ------------------------------------------------------------- tracking

  onPlayerChanged: resyncPosition()
  onTrackSignatureChanged: resyncPosition()
  onPlayingChanged: resyncPosition()
  Component.onCompleted: resyncPosition()

  // Interpolates between samples while playing; stops entirely when paused or
  // when no Plexamp player is on the bus, so an idle bar costs nothing.
  Timer {
    interval: 250
    repeat: true
    running: root.playing
    // Guarded: a plugin reload tears the service down while the timer is still
    // armed, and the last tick then fires against a null root.
    onTriggered: if (root) root.updatePosition()
  }

  // Corrects drift and catches seeks made inside Plexamp itself.
  Timer {
    interval: 3000
    repeat: true
    running: root.running
    onTriggered: if (root) root.resyncPosition()
  }

  function statusJson() {
    return JSON.stringify({
      running: root.running,
      playing: root.playing,
      hasTrack: root.hasTrack,
      title: root.title,
      artist: root.artist,
      album: root.album,
      artUrl: root.artUrl,
      position: Math.round(root.position),
      length: Math.round(root.length),
      shuffle: root.shuffle,
      loopState: root.loopState === MprisLoopState.Track
        ? "track" : (root.loopState === MprisLoopState.Playlist ? "playlist" : "none"),
      volume: root.volumeSupported ? Math.round(root.volume * 100) : -1,
      canGoNext: root.canGoNext,
      canGoPrevious: root.canGoPrevious,
      canSeek: root.canSeek
    })
  }

  // Keybinding surface: `omarchy-shell plexamp <method>`.
  IpcHandler {
    target: "plexamp"

    function status(): string { return root.statusJson() }
    function playPause(): string { return root.playPause() ? "ok" : "unhandled" }
    function play(): string { return root.play() ? "ok" : "unhandled" }
    function pause(): string { return root.pause() ? "ok" : "unhandled" }
    function next(): string { return root.next() ? "ok" : "unhandled" }
    function previous(): string { return root.previous() ? "ok" : "unhandled" }
    function seekForward(): string { return root.seekBy(root.seekStep) ? "ok" : "unhandled" }
    function seekBack(): string { return root.seekBy(-root.seekStep) ? "ok" : "unhandled" }
    function shuffle(): string { return root.toggleShuffle() ? "ok" : "unhandled" }
    function repeat(): string { return root.cycleLoop() ? "ok" : "unhandled" }
    function volumeUp(): string { return root.nudgeVolume(0.05) ? "ok" : "unhandled" }
    function volumeDown(): string { return root.nudgeVolume(-0.05) ? "ok" : "unhandled" }
    function togglePanel(): string { root.panelRequested("toggle"); return "ok" }
    function showPanel(): string { root.panelRequested("open"); return "ok" }
    function hidePanel(): string { root.panelRequested("close"); return "ok" }
    function raise(): string { return root.raiseOrLaunch() ? "ok" : "unhandled" }
    function launch(): string { return root.launch() ? "ok" : "unhandled" }
    function ping(): string { return "ok" }
  }
}

.pragma library

// Pure helpers for the Plexamp plugin. Everything here is side-effect free so
// it can be reasoned about without a running shell: player matching, label
// formatting, and the small amount of math the panel needs.

var PLAYER_HINTS = ["plexamp", "plex-amp"]

function lower(value) {
  return String(value === undefined || value === null ? "" : value).toLowerCase()
}

// Plexamp publishes org.mpris.MediaPlayer2.plexamp, but AppImage, Flatpak, and
// headless builds have each shipped a different identity string at some point,
// so match on any of the three fields MPRIS gives us.
function isPlexamp(player) {
  if (!player) return false
  var haystack = [player.dbusName, player.identity, player.desktopEntry].map(lower).join(" ")
  for (var i = 0; i < PLAYER_HINTS.length; i++)
    if (haystack.indexOf(PLAYER_HINTS[i]) !== -1) return true
  return false
}

// Plexamp only ever exports one player, but a stale bus name can linger for a
// moment after a restart. Prefer the one that is playing, then the one with
// track metadata, so the bar never binds to the corpse.
function pickPlayer(players) {
  if (!players) return null
  var candidates = []
  for (var i = 0; i < players.length; i++)
    if (isPlexamp(players[i])) candidates.push(players[i])
  if (candidates.length === 0) return null

  var playing = null
  var withTrack = null
  for (var j = 0; j < candidates.length; j++) {
    var p = candidates[j]
    if (!playing && p.isPlaying) playing = p
    if (!withTrack && (p.trackTitle || p.trackArtist)) withTrack = p
  }
  return playing || withTrack || candidates[0]
}

function hasTrack(player) {
  return !!(player && (player.trackTitle || player.trackArtist))
}

function artistOf(player) {
  if (!player) return ""
  return String(player.trackArtist || player.trackAlbumArtist || "")
}

function trackSignature(player) {
  if (!player) return ""
  return [player.trackTitle, artistOf(player), player.trackAlbum].join("|")
}

// m:ss below an hour, h:mm:ss above it. Negative and non-finite values render
// as a placeholder rather than "NaN:aN" in the seek row.
function formatTime(seconds) {
  var total = Math.floor(Number(seconds))
  if (!isFinite(total) || total < 0) return "--:--"
  var hours = Math.floor(total / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  var secs = total % 60
  var pad = function (n) { return n < 10 ? "0" + n : String(n) }
  return hours > 0 ? hours + ":" + pad(minutes) + ":" + pad(secs) : minutes + ":" + pad(secs)
}

function clamp(value, minimum, maximum) {
  var n = Number(value)
  if (!isFinite(n)) return minimum
  return Math.max(minimum, Math.min(maximum, n))
}

function progressFraction(position, length) {
  if (!isFinite(length) || length <= 0) return 0
  return clamp(position / length, 0, 1)
}

// Glyphs are Nerd Font Material Design icons, the same family the first-party
// media widget draws with.
function volumeIcon(volume) {
  if (!isFinite(volume) || volume <= 0.001) return "󰝟"
  if (volume < 0.34) return "󰕿"
  if (volume < 0.67) return "󰖀"
  return "󰕾"
}

var DEFAULT_LABEL_FORMAT = "{title}  ·  {artist}"

// Track metadata comes from the tags in a media file, which are attacker- or
// corruption-controlled input. `labelMode: "full"` deliberately removes the
// width cap, so without a bound here a pathological title would size the chip
// to whatever the tag says on every monitor's bar. These limits are far above
// any real title and exist only to stop that.
var MAX_LABEL_CHARS = 160
var MAX_TOOLTIP_CHARS = 300

function ellipsize(text, limit) {
  var s = String(text)
  return s.length > limit ? s.slice(0, limit - 1) + "…" : s
}

// Drops a separator left stranded by an empty field, so a track with no artist
// reads "Title" rather than "Title  ·  ". Only separators with whitespace on
// the outer side are touched, so a hyphen inside a name ("AC-DC") survives.
function tidySeparators(text) {
  return String(text)
    .replace(/\s*[·—–|-]\s*[·—–|-]\s*/g, "  ·  ")
    .replace(/^\s*[·—–|-]\s+/, "")
    .replace(/\s+[·—–|-]\s*$/, "")
    .replace(/\s{3,}/g, "  ")
    .trim()
}

function labelFor(player, format) {
  if (!hasTrack(player)) return ""
  var title = String(player.trackTitle || "")
  var artist = artistOf(player)
  var album = player && player.trackAlbum ? String(player.trackAlbum) : ""

  var template = format && String(format).length > 0
    ? String(format) : DEFAULT_LABEL_FORMAT

  var out = template
    .replace(/\{title\}/g, title)
    .replace(/\{artist\}/g, artist)
    .replace(/\{album\}/g, album)

  out = tidySeparators(out)
  // An empty result means the template referenced only fields this track
  // lacks; fall back rather than showing a blank chip.
  return ellipsize(out.length > 0 ? out : (title || artist), MAX_LABEL_CHARS)
}

function tooltipFor(player) {
  if (!hasTrack(player)) return "Plexamp"
  var parts = []
  if (player.trackTitle) parts.push(String(player.trackTitle))
  var artist = artistOf(player)
  if (artist) parts.push(artist)
  if (player.trackAlbum) parts.push(String(player.trackAlbum))
  return ellipsize(parts.join(" — "), MAX_TOOLTIP_CHARS)
}

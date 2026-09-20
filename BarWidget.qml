import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "PlexampModel.js" as PlexampModel

// Bar chip: cover art, play state, and a scrolling track label, with the
// player panel hanging off it. All playback state comes from the plugin's own
// service, so every monitor's copy of the widget shows the same thing.
BarWidget {
  id: root
  moduleName: "nodrej.plexamp"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("nodrej.plexamp") : null

  readonly property bool running: !!(service && service.running)
  readonly property bool playing: !!(service && service.playing)
  readonly property bool hasTrack: !!(service && service.hasTrack)
  readonly property string label: service ? PlexampModel.labelFor(service.player) : ""

  readonly property bool showArt: setting("showArt", true)
  readonly property bool showLabel: setting("showLabel", true)
  readonly property int labelWidth: Math.max(Style.space(40), setting("labelWidth", 180))
  readonly property bool scrollLabel: setting("scrollLabel", true)
  readonly property string visibility: setting("visibility", "when-running")
  readonly property string leftClick: setting("leftClick", "panel")
  readonly property string wheelAction: setting("wheelAction", "track")

  property bool popupOpen: false

  function close() { popupOpen = false }

  // One widget instance exists per monitor, so an IPC-driven panel has to pick
  // a screen. Opening on the focused monitor (and closing everywhere else) is
  // what a keybinding means by "show me the player".
  readonly property string screenName: {
    var window = root.QsWindow.window
    return window && window.screen ? String(window.screen.name) : ""
  }

  readonly property bool onFocusedScreen: {
    var focused = Hyprland.focusedMonitor
    if (!focused || !focused.name || screenName === "") return true
    return String(focused.name) === screenName
  }

  function openPopup() { popupOpen = onFocusedScreen }
  function closePopup() { popupOpen = false }
  function togglePopup() { popupOpen = onFocusedScreen ? !popupOpen : false }

  // The service is shared; the widget is where the user's inline shell.json
  // settings live, so push the two the service needs down to it.
  function syncService() {
    if (!service) return
    service.launchCommand = String(setting("launchCommand", "plexamp.desktop"))
    service.seekStep = Math.max(1, setting("seekStep", 10))
  }

  onServiceChanged: syncService()
  onSettingsChanged: syncService()
  Component.onCompleted: syncService()

  visible: visibility === "always" || (visibility === "when-playing" ? playing : running)
  implicitWidth: vertical ? barSize : (visible ? row.implicitWidth + Style.space(14) : 0)
  implicitHeight: vertical ? (visible ? row.implicitHeight + Style.space(10) : 0) : barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Rectangle {
      id: artThumb
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(16)
      height: Style.space(16)
      radius: Style.space(3)
      clip: true
      color: Util.alpha(root.bar ? root.bar.barForeground : Color.foreground, 0.15)
      visible: root.showArt && root.hasTrack && artImage.status === Image.Ready

      Image {
        id: artImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: Style.space(48)
        sourceSize.height: Style.space(48)
        source: root.service && root.service.artUrl ? root.service.artUrl : ""
      }
    }

    Text {
      id: glyph
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: root.running ? (root.playing ? "󰏤" : "󰐊") : "󰝚"
      color: root.playing
        ? (root.bar ? root.bar.barForeground : Color.foreground)
        : Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.5)
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body

      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: 160 }
      }
    }

    // Vertical bars have no room for a label, so the chip collapses to art
    // plus play state there.
    Item {
      id: scrollClip
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(root.labelWidth, labelText.implicitWidth)
      height: glyph.height
      clip: true
      visible: !root.vertical && root.showLabel && root.label !== ""

      Text {
        id: labelText
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.label
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body

        readonly property bool needsScroll: implicitWidth > scrollClip.width

        // Marquee only while the popup is closed: a label sliding under an open
        // panel reads as a glitch, and the panel already shows the full title.
        NumberAnimation on x {
          running: root.scrollLabel && labelText.needsScroll && !root.popupOpen && scrollClip.visible
          loops: Animation.Infinite
          duration: Math.max(6000, labelText.implicitWidth * 25)
          from: scrollClip.width
          to: -labelText.implicitWidth
          easing.type: Easing.Linear
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function (mouse) {
      if (!root.service) return

      // With Plexamp closed the chip is a launcher, whatever the click map says.
      if (!root.running) {
        if (mouse.button === Qt.LeftButton) root.service.launch()
        else root.popupOpen = !root.popupOpen
        return
      }

      if (mouse.button === Qt.MiddleButton) {
        root.service.next()
      } else if (mouse.button === Qt.RightButton) {
        if (root.leftClick === "panel") root.service.playPause()
        else root.popupOpen = !root.popupOpen
      } else {
        if (root.leftClick === "panel") root.popupOpen = !root.popupOpen
        else root.service.playPause()
      }
    }

    onWheel: function (wheel) {
      if (!root.service || !root.running || root.wheelAction === "none") return
      var up = wheel.angleDelta.y > 0
      if (root.wheelAction === "volume") root.service.nudgeVolume(up ? 0.05 : -0.05)
      else if (up) root.service.previous()
      else root.service.next()
    }

    onEntered: if (root.bar) root.bar.showTooltip(root, root.running
      ? (root.service ? PlexampModel.tooltipFor(root.service.player) : "Plexamp")
      : "Plexamp — click to launch")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(panel.implicitHeight)

    PlexampPanel {
      id: panel
      width: parent.width
      bar: root.bar
      service: root.service
    }
  }

  // `omarchy-shell plexamp-panel toggle` — bindable to a key. Only one handler
  // per target can register, so it relays to the per-monitor instances.
  IpcHandler {
    target: "plexamp-panel"

    function toggle(): string { root.broadcast("togglePopup"); return "ok" }
    function open(): string { root.broadcast("openPopup"); return "ok" }
    function close(): string { root.broadcast("closePopup"); return "ok" }
  }
}

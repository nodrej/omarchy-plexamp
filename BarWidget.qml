import QtQuick
import Quickshell
import Quickshell.Hyprland

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
  readonly property string labelFormat: String(setting("labelFormat", PlexampModel.DEFAULT_LABEL_FORMAT))
  readonly property string label: service ? PlexampModel.labelFor(service.player, labelFormat) : ""

  readonly property bool showArt: setting("showArt", true)
  readonly property bool showLabel: setting("showLabel", true)
  readonly property bool showProgress: setting("showProgress", true)
  readonly property int labelWidth: Math.max(Style.space(40), setting("labelWidth", 180))

  // "full"     — chip grows to the whole title, nothing hidden (wide monitors)
  // "scroll"   — capped at labelWidth, marquees what overflows
  // "truncate" — capped at labelWidth, elides with an ellipsis
  //
  // scrollLabel predates this setting; honour it when labelMode is unset so
  // existing configs keep the behaviour they already had.
  readonly property string labelMode: {
    var mode = String(setting("labelMode", ""))
    if (mode === "full" || mode === "scroll" || mode === "truncate") return mode
    return setting("scrollLabel", true) ? "scroll" : "truncate"
  }
  readonly property string visibility: setting("visibility", "when-running")
  readonly property string leftClick: setting("leftClick", "panel")
  readonly property string wheelAction: setting("wheelAction", "track")
  readonly property string middleClick: setting("middleClick", "next")

  // "all"     — a chip on every monitor's bar (one widget instance each)
  // "focused" — only on the monitor that currently has focus
  // "named"   — only on the monitors listed in `monitors`
  readonly property string monitorMode: setting("monitorMode", "all")
  readonly property var monitorList: setting("monitors", [])

  readonly property bool onChosenScreen: {
    if (monitorMode === "focused") return onFocusedScreen
    if (monitorMode === "named") {
      if (!monitorList || monitorList.length === 0) return true
      if (screenName === "") return true
      for (var i = 0; i < monitorList.length; i++) {
        if (String(monitorList[i]) === screenName) return true
      }
      return false
    }
    return true
  }

  property bool popupOpen: false

  function close() { popupOpen = false }

  // `settings` is read-only — it mirrors this widget's entry in shell.json.
  // Persisting a change means asking Omarchy to rewrite that entry; the shell
  // watches the file, so the new value arrives back through `settings` without
  // us having to touch it here.
  //
  // `--json` matters: without it every value is written as a string, and the
  // string "false" is truthy on the way back in, so a boolean toggle would
  // only ever turn things on.
  function setSetting(key, value, asJson) {
    var args = ["omarchy", "bar", "set", moduleName, key, String(value)]
    if (asJson) args.push("--json")
    Quickshell.execDetached(args)
  }

  function setLabelMode(mode) {
    if (mode !== "full" && mode !== "scroll" && mode !== "truncate") return
    setSetting("labelMode", mode, false)
  }

  function toggleSetting(key, current) { setSetting(key, !current, true) }

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

  visible: onChosenScreen
    && (visibility === "always" || (visibility === "when-playing" ? playing : running))
  implicitWidth: vertical ? barSize : (visible ? row.implicitWidth + Style.space(14) : 0)
  implicitHeight: vertical ? (visible ? row.implicitHeight + Style.space(10) : 0) : barSize

  // Playback progress as a hairline under the chip. The service already
  // interpolates `progress` for the panel's seek bar, so this costs nothing
  // beyond drawing it.
  Rectangle {
    id: progressTrack
    visible: !root.vertical && root.showProgress && root.hasTrack
             && !!(root.service && root.service.length > 0)
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(3)
    anchors.leftMargin: Style.space(5)
    anchors.rightMargin: Style.space(5)
    height: Math.max(1, Style.space(2))
    radius: height / 2
    color: Qt.rgba(root.bar ? root.bar.barForeground.r : 1,
                   root.bar ? root.bar.barForeground.g : 1,
                   root.bar ? root.bar.barForeground.b : 1, 0.18)

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * Math.max(0, Math.min(1, root.service ? root.service.progress : 0))
      radius: parent.radius
      color: root.playing
        ? (root.bar ? root.bar.barForeground : Color.foreground)
        : Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.6)

      Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }
    }
  }

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
      // "full" lets the chip grow to the whole title; the other modes cap it
      // at labelWidth and either marquee or elide what overflows.
      width: root.labelMode === "full"
        ? labelText.implicitWidth
        : Math.min(root.labelWidth, labelText.implicitWidth)
      height: glyph.height
      clip: root.labelMode !== "full"
      visible: !root.vertical && root.showLabel && root.label !== ""

      Text {
        id: labelText
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.label
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body

        // Eliding needs a bounded width; the other modes size to the text and
        // let the clip rectangle do the cutting.
        width: root.labelMode === "truncate" ? scrollClip.width : implicitWidth
        elide: root.labelMode === "truncate" ? Text.ElideRight : Text.ElideNone

        readonly property bool needsScroll: root.labelMode === "scroll"
          && implicitWidth > scrollClip.width

        // How far the label must travel for its tail to reach the right edge.
        // Going further only pushes the text out into blank space.
        readonly property real scrollDistance: Math.max(0, implicitWidth - scrollClip.width)

        // Marquee only while the popup is closed: a label sliding under an open
        // panel reads as a glitch, and the panel already shows the full title.
        //
        // The cycle holds at the start so the title is readable from the top,
        // scrolls just far enough to expose the tail, then holds again. The
        // previous animation ran from fully off-right to fully off-left, so the
        // label was never aligned and every glance caught a fragment mid-flight.
        SequentialAnimation on x {
          running: labelText.needsScroll && !root.popupOpen && scrollClip.visible
          loops: Animation.Infinite

          PropertyAction { value: 0 }
          PauseAnimation { duration: 2500 }
          NumberAnimation {
            from: 0
            to: -labelText.scrollDistance
            duration: Math.max(1200, labelText.scrollDistance * 28)
            easing.type: Easing.InOutQuad
          }
          PauseAnimation { duration: 2500 }
        }

        // Put a previously scrolled label back instead of leaving it wherever
        // the animation stopped when the mode or the track changes.
        onNeedsScrollChanged: if (!needsScroll) x = 0
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
        if (root.middleClick === "next") root.service.next()
        else if (root.middleClick === "previous") root.service.previous()
        else if (root.middleClick === "playPause") root.service.playPause()
        else if (root.middleClick === "panel") root.popupOpen = !root.popupOpen
        // "none" falls through and does nothing.
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
      // The panel's settings view reads and writes the widget's own inline
      // settings, so it needs the widget itself, not just the shared service.
      widget: root

      // Reopening the chip should land on the player, not wherever the last
      // visit left off.
      onVisibleChanged: if (!visible) settingsOpen = false
    }
  }

  // `omarchy-shell plexamp togglePanel` lands on the service, which fans the
  // request out to every monitor's widget; only the focused one opens.
  Connections {
    target: root.service

    function onPanelRequested(mode) {
      if (mode === "open") root.openPopup()
      else if (mode === "close") root.closePopup()
      else root.togglePopup()
    }
  }
}

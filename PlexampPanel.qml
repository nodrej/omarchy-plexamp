import QtQuick
import qs.Commons
import qs.Ui
import "PlexampModel.js" as PlexampModel

// Player panel shown under the bar widget: cover, track, scrubbable seek bar,
// transport with shuffle and repeat, and volume. Sized by implicitHeight so
// PopupCard can fit itself around whatever state we are in.
Item {
  id: root

  property QtObject bar: null
  property var service: null
  property int artSize: Style.space(76)

  readonly property bool running: !!(service && service.running)
  readonly property bool hasTrack: !!(service && service.hasTrack)
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  implicitHeight: running ? playerColumn.implicitHeight : emptyColumn.implicitHeight

  // ------------------------------------------------------------ not running

  Column {
    id: emptyColumn
    width: parent.width
    spacing: Style.space(12)
    visible: !root.running

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "󰝚"
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.displayLarge
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      textFormat: Text.PlainText
      text: "Plexamp isn't running"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
    }

    Button {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Open Plexamp"
      iconText: "󰏌"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: if (root.service) root.service.launch()
    }
  }

  // ---------------------------------------------------------------- playing

  Column {
    id: playerColumn
    width: parent.width
    spacing: Style.space(12)
    visible: root.running

    Row {
      width: parent.width
      spacing: Style.space(12)

      BorderSurface {
        id: artFrame
        width: root.artSize
        height: root.artSize
        radius: Style.spacing.labelGap
        color: Style.normalFillFor(root.foreground, Color.accent)
        borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

        Item {
          anchors.fill: parent
          anchors.margins: Style.space(2)
          clip: true

          Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            // Plexamp hands out server-hosted art, so ask for it at the size we
            // draw rather than decoding a 1200px cover for a 76px frame.
            sourceSize.width: root.artSize * 2
            sourceSize.height: root.artSize * 2
            source: root.service && root.service.artUrl ? root.service.artUrl : ""
            visible: source !== "" && status === Image.Ready
          }

          Text {
            anchors.centerIn: parent
            visible: !root.service || !root.service.artUrl
            text: "󰝚"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }
      }

      Column {
        width: parent.width - artFrame.width - Style.space(12)
        spacing: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.service && root.service.title ? root.service.title : "Nothing playing"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.service ? root.service.artist : ""
          color: Qt.darker(root.foreground, 1.3)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          visible: text !== ""
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.service ? root.service.album : ""
          color: Qt.darker(root.foreground, 1.6)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          visible: text !== ""
        }
      }
    }

    // ------------------------------------------------------------ seek bar

    Column {
      width: parent.width
      spacing: Style.space(2)
      visible: root.hasTrack

      PanelSlider {
        id: seekSlider
        bar: root.bar
        width: parent.width
        minimum: 0
        maximum: root.service && root.service.length > 0 ? root.service.length : 1
        step: 5
        enabled: !!(root.service && root.service.canSeek && root.service.length > 0)
        opacity: enabled ? 1.0 : 0.45
        value: root.service ? root.service.position : 0

        // Seek on release only: dragging across a track would otherwise fire a
        // SetPosition call per pixel and make Plexamp stutter.
        onReleased: function (v) { if (root.service) root.service.seekTo(v) }
      }

      Item {
        width: parent.width
        height: elapsedLabel.implicitHeight

        Text {
          id: elapsedLabel
          anchors.left: parent.left
          textFormat: Text.PlainText
          text: seekSlider.dragging
            ? PlexampModel.formatTime(seekSlider.liveValue)
            : (root.service ? root.service.positionLabel : "--:--")
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          anchors.right: parent.right
          textFormat: Text.PlainText
          text: root.service ? root.service.lengthLabel : "--:--"
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    // ----------------------------------------------------------- transport

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.space(4)

      Button {
        iconText: root.service && root.service.shuffle ? "󰒝" : "󰒞"
        tooltipText: root.service && root.service.shuffle ? "Shuffle on" : "Shuffle off"
        foreground: root.foreground
        fontFamily: root.fontFamily
        selected: !!(root.service && root.service.shuffle)
        enabled: !!(root.service && root.service.shuffleSupported)
        opacity: enabled ? 1.0 : 0.35
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        onClicked: if (root.service) root.service.toggleShuffle()
      }

      Button {
        iconText: "󰒮"
        tooltipText: "Previous"
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: !!(root.service && root.service.canGoPrevious)
        opacity: enabled ? 1.0 : 0.35
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        onClicked: if (root.service) root.service.previous()
      }

      Button {
        iconText: root.service && root.service.playing ? "󰏤" : "󰐊"
        tooltipText: root.service && root.service.playing ? "Pause" : "Play"
        foreground: root.foreground
        fontFamily: root.fontFamily
        iconSize: Style.font.iconLarge
        enabled: !!(root.service && root.service.canTogglePlaying)
        opacity: enabled ? 1.0 : 0.35
        horizontalPadding: Style.spacing.panelGap
        verticalPadding: Style.spacing.controlPaddingY
        onClicked: if (root.service) root.service.playPause()
      }

      Button {
        iconText: "󰒭"
        tooltipText: "Next"
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: !!(root.service && root.service.canGoNext)
        opacity: enabled ? 1.0 : 0.35
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        onClicked: if (root.service) root.service.next()
      }

      Button {
        // 0 = none, 1 = track, 2 = playlist (MprisLoopState); the service owns
        // the enum, the panel only needs the three glyphs.
        iconText: root.service && root.service.loopState === 1
          ? "󰑘" : (root.service && root.service.loopState === 2 ? "󰑖" : "󰑗")
        tooltipText: root.service && root.service.loopState === 1
          ? "Repeat track" : (root.service && root.service.loopState === 2 ? "Repeat queue" : "Repeat off")
        foreground: root.foreground
        fontFamily: root.fontFamily
        selected: !!(root.service && root.service.loopState !== 0)
        enabled: !!(root.service && root.service.loopSupported)
        opacity: enabled ? 1.0 : 0.35
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        onClicked: if (root.service) root.service.cycleLoop()
      }
    }

    PanelSeparator {
      foreground: root.foreground
      visible: root.service && root.service.volumeSupported
    }

    // -------------------------------------------------------------- volume

    Row {
      width: parent.width
      spacing: Style.space(8)
      visible: !!(root.service && root.service.volumeSupported)

      Text {
        id: volumeGlyph
        anchors.verticalCenter: parent.verticalCenter
        text: PlexampModel.volumeIcon(root.service ? root.service.volume : 0)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        width: Style.space(20)
        horizontalAlignment: Text.AlignHCenter
      }

      PanelSlider {
        bar: root.bar
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - volumeGlyph.width - Style.space(8)
        minimum: 0
        maximum: 1
        step: 0.05
        value: root.service ? root.service.volume : 0
        onMoved: function (v) { if (root.service) root.service.setVolume(v) }
      }
    }

    Button {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Open Plexamp"
      iconText: "󰏌"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      fontSize: Style.font.bodySmall
      onClicked: if (root.service) root.service.raiseOrLaunch()
    }
  }
}

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

// Right-click menu for a dock entry, macOS-Dock style: the app's windows on
// this workspace, then Quit / Force Quit (hold Alt). One overlay per bar
// widget; MenuOwner.js guarantees only one is open across monitors.
//
// It is a transparent full-screen layer with exclusive keyboard focus, so
// Escape and Alt reach it and a click anywhere outside the box closes it
// (the bar itself never has keyboard focus). Pattern credit:
// seunghan91/omarchy-glance-dock MenuOverlay.qml (MIT).
PanelWindow {
  id: overlay

  required property QtObject dock
  readonly property var entry: dock ? dock.menuEntry : null
  readonly property var win: entry && entry.win !== undefined ? entry.win : null
  property bool force: false

  screen: overlay.dock && overlay.dock.QsWindow && overlay.dock.QsWindow.window
    ? overlay.dock.QsWindow.window.screen
    : null
  visible: dock && dock.menuOpen && win !== null
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "appdock-menu"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  onVisibleChanged: {
    if (!visible) return
    overlay.force = false
    Qt.callLater(function() { if (overlay.visible) keys.forceActiveFocus() })
  }

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

  // Clicks anywhere outside the box close the menu.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    onPressed: if (overlay.dock) overlay.dock.closeMenu()
  }

  Item {
    id: keys
    anchors.fill: parent
    focus: true
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) { overlay.dock.closeMenu(); event.accepted = true }
      else if (event.key === Qt.Key_Alt || (event.modifiers & Qt.AltModifier)) overlay.force = true
    }
    Keys.onReleased: function(event) {
      if (event.key === Qt.Key_Alt) overlay.force = false
    }
  }

  Rectangle {
    id: box

    // The dock fills menuX/menuY (pointer position, screen-local) before the
    // overlay becomes visible.
    readonly property real px: overlay.dock ? overlay.dock.menuX : 0
    readonly property real py: overlay.dock ? overlay.dock.menuY : 0
    width: 260
    height: menuColumn.implicitHeight + 2
    x: overlay.clamp(px - width / 2, 4, Math.max(4, overlay.width - width - 4))
    y: overlay.clamp(py + 8, 4, Math.max(4, overlay.height - height - 4))
    color: Color.popups.background
    border.width: 1
    border.color: Color.popups.border
    radius: Style.radius

    // Clicks on the box itself (border, separator) stay inside the menu.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    Column {
      id: menuColumn
      x: 1
      y: 1
      width: box.width - 2

      component MenuRow: Rectangle {
        id: menuRow
        property string label: ""
        property bool checked: false
        property bool strong: false
        property bool danger: false
        signal activated()
        width: parent ? parent.width : 180
        height: 28
        color: Color.popups.background
        Rectangle {
          anchors.fill: parent
          color: Color.popups.text
          opacity: rowMouse.containsMouse ? (menuRow.danger ? 0.14 : 0.08) : 0
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          x: 10
          width: parent.width - 20
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: (menuRow.checked ? "• " : "  ") + menuRow.label
          color: Color.popups.text
          font.pixelSize: Style.font.body
          font.bold: menuRow.strong || menuRow.danger
        }
        MouseArea {
          id: rowMouse
          hoverEnabled: true
          anchors.fill: parent
          onClicked: menuRow.activated()
        }
      }

      // The app's windows on this workspace, live-filtered while open.
      // The explicit reads of menuEntry and windows create the reactive
      // dependencies (a bare function call would evaluate once, forever).
      readonly property var menuWindows: {
        var e = overlay.dock ? overlay.dock.menuEntry : null
        var all = overlay.dock ? overlay.dock.windows : []
        return overlay.dock && e ? overlay.dock.windowsForMenu() : []
      }

      Flickable {
        id: windowList
        width: parent.width
        height: Math.min(windowRows.implicitHeight,
          Math.max(28, overlay.height - 8 - 2 - 1 - 28 - 28))
        contentHeight: windowRows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: windowRows
          width: windowList.width

          Repeater {
            model: menuColumn.menuWindows
            MenuRow {
              required property var modelData
              label: overlay.dock && overlay.dock.titleFor(modelData)
              checked: overlay.dock && overlay.dock.isFocused(modelData)
              onActivated: {
                var w = modelData
                overlay.dock.closeMenu()
                overlay.dock.activateWindow(w)
              }
            }
          }
        }
      }

      Rectangle { width: parent.width; height: 1; color: Color.popups.border; opacity: 0.5 }

      MenuRow {
        label: overlay.force ? "Force Quit" : "Quit"
        strong: overlay.force
        danger: overlay.force
        onActivated: {
          var w = overlay.win
          overlay.dock.closeMenu()
          overlay.dock.quitWindow(w, overlay.force)
        }
      }
    }
  }
}

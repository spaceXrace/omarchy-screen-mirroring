import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "spacexrace.screen-mirroring"
  readonly property color foreground: bar ? bar.foreground : Color.foreground

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    hasVisualContent: true
    tooltipText: panelLoader.item && panelLoader.item.connectedReceiver ? "Mirroring to " + panelLoader.item.connectedReceiver : "Screen Mirroring"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
    MirrorIcon {
      anchors.centerIn: parent
      size: 17
      foreground: panelLoader.item && panelLoader.item.streaming ? root.foreground : Qt.darker(root.foreground, 1.28)
    }
  }

  component MirrorIcon: Item {
    property real size: 16
    property color foreground: "white"
    width: size
    height: size
    Rectangle { x: parent.width * 0.22; y: parent.height * 0.16; width: parent.width * 0.70; height: parent.height * 0.46; color: "transparent"; border.color: Qt.darker(parent.foreground, 1.3); border.width: 1.4; radius: 1 }
    Rectangle { x: parent.width * 0.07; y: parent.height * 0.31; width: parent.width * 0.70; height: parent.height * 0.46; color: "transparent"; border.color: parent.foreground; border.width: 1.4; radius: 1 }
  }
}

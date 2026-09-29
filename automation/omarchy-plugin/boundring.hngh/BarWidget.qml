import QtQuick
import Quickshell
import qs.Ui

// hngh bar widget: operator queue count + panel toggle. Mirrors the
// built-in clock plugin contract (bar-widget loads its Panel.qml via a
// Loader and forwards the panel lifecycle Quattro uses).
BarWidget {
  id: root
  moduleName: "boundring.hngh"

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  // -1 = dashboard unreachable (fail-open display, never a fake zero)
  property int operatorQueue: -1
  property var items: []

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  function refresh() {
    const xhr = new XMLHttpRequest();
    xhr.open("GET", "http://127.0.0.1:8890/newspaper.json");
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== XMLHttpRequest.DONE) return;
      if (xhr.status !== 200) {
        root.operatorQueue = -1;
        root.items = [];
        return;
      }
      try {
        const d = JSON.parse(xhr.responseText);
        root.operatorQueue = (d.queues && d.queues.operator) || 0;
        root.items = (d.articles || []).filter(function (a) {
          return a.category === "operator"
            && Array.isArray(a.choices) && a.choices.length;
        });
      } catch (e) {
        root.operatorQueue = -1;
        root.items = [];
      }
    };
    xhr.send();
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.operatorQueue < 0 ? "hngh ?" : "hngh " + root.operatorQueue
    tooltipText: "hngh automation desk"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}

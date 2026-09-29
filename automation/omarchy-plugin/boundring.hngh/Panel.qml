import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

// hngh desk panel: operator decision cards with one-click handle/park.
// Loaded by BarWidget.qml (clock pattern). Read-only except the six
// allowlisted operator-item endpoints; the park action always carries
// the operator's note (the dashboard rejects a noteless park).
Panel {
  id: root
  moduleName: "boundring.hngh"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var widget: hostWidget

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function closeForPopoutSwitch() { root.close() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function post(endpoint, payload) {
    const xhr = new XMLHttpRequest();
    xhr.open("POST", "http://127.0.0.1:8890" + endpoint);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.onreadystatechange = function () {
      if (xhr.readyState === XMLHttpRequest.DONE && root.widget)
        root.widget.refresh();
    };
    xhr.send(JSON.stringify(payload));
  }

  readonly property string ink: root.bar ? root.barForeground : Style.foreground

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        Text {
          width: parent.width
          text: root.widget
            ? "hngh desk · operator queue " + Math.max(0, root.widget.operatorQueue)
            : "hngh desk"
          color: root.ink
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          width: parent.width
          visible: !root.widget || root.widget.items.length === 0
          text: "no decision cards on the desk (dashboard unreachable or queue clear)"
          color: root.ink
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: root.widget ? root.widget.items : []

          delegate: Column {
            id: card
            width: parent.width
            spacing: Style.space(6)
            required property var modelData

            Text {
              width: parent.width
              text: card.modelData.headline || card.modelData.id || "operator item"
              color: root.ink
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Row {
              spacing: Style.space(6)

              Rectangle {
                width: handleLabel.implicitWidth + 16
                height: 24
                radius: 4
                color: handleMa.containsMouse
                  ? Qt.lighter("#4a6b3a") : "#4a6b3a"

                Text {
                  id: handleLabel
                  anchors.centerIn: parent
                  text: "handle"
                  color: "white"
                  font.pixelSize: 11
                }

                MouseArea {
                  id: handleMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.post("/operator-item/handle",
                                       { id: card.modelData.id })
                }
              }

              TextField {
                id: parkNote
                width: 140
                height: 24
                font.pixelSize: 11
                placeholderText: "guidance note…"
                color: root.ink
              }

              Rectangle {
                width: parkLabel.implicitWidth + 16
                height: 24
                radius: 4
                color: parkNote.text.length === 0
                  ? "#777777"
                  : (parkMa.containsMouse ? Qt.lighter("#8a4a2a") : "#8a4a2a")

                Text {
                  id: parkLabel
                  anchors.centerIn: parent
                  text: "park"
                  color: "white"
                  font.pixelSize: 11
                }

                MouseArea {
                  id: parkMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: parkNote.text.length === 0
                    ? Qt.ArrowCursor : Qt.PointingHandCursor
                  enabled: parkNote.text.length > 0
                  onClicked: {
                    root.post("/operator-item/park",
                              { id: card.modelData.id, note: parkNote.text });
                    parkNote.text = "";
                  }
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          text: "open the full broadsheet →"
          color: root.ink
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          font.underline: true

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally("http://127.0.0.1:8890/")
          }
        }
      }
    }
  }
}

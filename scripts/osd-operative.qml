// osd-operative.qml — the desktop on-screen display (OSD) overlay.
//
// A standalone, frameless, always-on-top, translucent QtQuick window
// showing the operative (animated v4 block-char figure), a state speech
// line, and a slim status strip. It is a dumb renderer: it polls the
// snapshot JSON written by scripts/osd-operative and draws it.
//
// Run from the repo root (QML_XHR_ALLOW_FILE_READ is required — Qt
// disables file:// XHR reads by default, and this window polls the
// snapshot JSON scripts/osd-operative writes):
//     QML_XHR_ALLOW_FILE_READ=1 qml6 scripts/osd-operative.qml
// (Qt 6 / qt6-declarative; the qml6 runtime). The window floats
// bottom-right of the primary screen; offset with trailing args
//     QML_XHR_ALLOW_FILE_READ=1 qml6 scripts/osd-operative.qml -- --x=40 --y=40
// Click-through (WindowTransparentForInput) is enabled for x11.
import QtQuick
import QtQuick.Window

Window {
    id: osd
    width: 320
    height: 434
    visible: true
    title: "hngh-osd"
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
           | Qt.WindowTransparentForInput
    color: "transparent"

    // Snapshot path written by scripts/osd-operative. 2s refresh;
    // defensive reads: bad JSON / missing file just keep the last good
    // document. The path is not overridable from QML (Qt.Environment is
    // unavailable in the pure-QtQuick window); tests exercise the feeder
    // directly with $HNGH_OSD_OUT instead.
    property string snapshotUrl: "file:///tmp/hngh-osd.json"
    property var doc: null
    property int frame: 0
    property int speechTick: 0

    // Offset from the bottom-right corner, from trailing args
    // "--x=N --y=M" (fall back to a 24px default margin).
    property int osdOffsetX: 24
    property int osdOffsetY: 24

    function argValue(name, fallback) {
        var args = Qt.application.arguments
        for (var i = 0; i < args.length; i++) {
            var a = String(args[i])
            if (a.indexOf(name + "=") === 0) {
                var v = parseInt(a.split("=")[1])
                if (!isNaN(v)) return v
            }
            if (a === name && i + 1 < args.length) {
                var v2 = parseInt(args[i + 1])
                if (!isNaN(v2)) return v2
            }
        }
        return fallback
    }

    // Position: bottom-right of the primary screen.
    Component.onCompleted: {
        osdOffsetX = argValue("--x", 24)
        osdOffsetY = argValue("--y", 24)
        osd.x = Math.max(0, Screen.width - osd.width - osdOffsetX)
        osd.y = Math.max(0, Screen.height - osd.height - osdOffsetY)
        osd.reload()
    }

    function reload() {
        var req = new XMLHttpRequest()
        req.open("GET", osd.snapshotUrl)
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE && req.status === 200) {
                try {
                    var parsed = JSON.parse(req.responseText)
                    if (parsed && typeof parsed === "object" && parsed.frames) {
                        osd.doc = parsed
                        osd.frame = 0
                    }
                } catch (e) { /* keep last good doc */ }
            }
        }
        req.send()
    }

    Timer {
        id: readTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: osd.reload()
    }

    // Animation beats, mirroring the TUI's phase loop:
    // base(1.2s) -> anticipation(0.25s) -> action(0.3s) -> settle(1.2s).
    Timer {
        id: animTimer
        interval: 1200
        repeat: true
        running: true
        property var beats: [1200, 250, 300, 1200]
        onTriggered: {
            osd.frame = (osd.frame + 1) % 4
            animTimer.interval = animTimer.beats[osd.frame]
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#0b0e11"
        radius: 10
        opacity: 0.88
        border.color: "#5af78e"
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // The operative — the animated ASCII figure, monospace.
            Text {
                id: figure
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.family: "monospace"
                font.pixelSize: 11
                color: "#5af78e"
                style: Text.Outline
                styleColor: "#000000"
                text: osd.doc && osd.doc.frames && osd.doc.frames[osd.frame]
                      ? osd.doc.frames[osd.frame] : ""
            }

            // Speech line, wrapped, muted.
            Text {
                id: speech
                width: parent.width
                font.family: "monospace"
                font.pixelSize: 12
                color: "#c8d0d8"
                wrapMode: Text.Wrap
                text: osd.doc && osd.doc.speech ? osd.doc.speech
                      : "The queue holds its breath."
            }

            Item { width: 1; height: 2 }  // spacer before status

            // Slim status strip: clock · queue N · lanes O · latest.
            Text {
                id: status
                width: parent.width
                font.family: "monospace"
                font.pixelSize: 10
                color: "#7a8695"
                elide: Text.ElideRight
                text: osd.doc && osd.doc.status ? osd.doc.status : ""
            }
        }
    }

    // Show the fail-closed message while still animating a figure when ok=false.
    Text {
        id: failMsg
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        visible: osd.doc && osd.doc.ok === false
        font.family: "monospace"
        font.pixelSize: 10
        color: "#e06c6c"
        width: parent.width * 0.9
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        text: osd.doc && osd.doc.msg ? osd.doc.msg : "data unavailable"
    }
}
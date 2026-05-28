import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // Cache data
    property int s5h: 0       // 5h utilization %
    property int s7d: 0       // 7d utilization %
    property int sr: 0        // 5h reset minutes
    property int wr: 0        // 7d reset minutes
    property string st: "unknown"  // status string
    property int ts: 0        // timestamp
    property bool cacheExists: false
    property bool isStale: false

    // Colors
    readonly property string claudeOrange: "#D97757"
    readonly property string warningAmber: "#E6961E"
    readonly property string criticalRed: "#DC3232"

    Plasmoid.status: cacheExists ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus

    function colorForPct(pct) {
        if (pct >= 95) return criticalRed;
        if (pct >= 75) return warningAmber;
        return claudeOrange;
    }

    function glyphForPct(pct) {
        if (pct < 50) return "◔";
        if (pct < 75) return "◑";
        if (pct < 95) return "◕";
        return "●";
    }

    function fmtReset(mins) {
        if (mins <= 0) return "now";
        var d = Math.floor(mins / (60 * 24));
        var h = Math.floor((mins % (60 * 24)) / 60);
        var m = mins % 60;
        if (d > 0) return d + "d " + h + "h " + m + "m";
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    function parseOutput(stdout) {
        var text = stdout.trim();
        if (!text) {
            cacheExists = false;
            return;
        }
        try {
            var data = JSON.parse(text);
            s5h = data.s || 0;
            s7d = data.w || 0;
            sr = data.sr || 0;
            wr = data.wr || 0;
            st = data.st || "unknown";
            ts = data.ts || 0;
            cacheExists = true;

            var now = Math.floor(Date.now() / 1000);
            isStale = (now - ts) >= 120;
        } catch (e) {
            cacheExists = false;
        }
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            var stdout = data["stdout"] || "";
            disconnectSource(source);
            parseOutput(stdout);
        }
    }

    function readCache() {
        // Append timestamp to avoid DataSource caching the command result
        var cmd = "cat \"$HOME/.claude/.claudemeter-quota\" 2>/dev/null || echo ''";
        if (executable.connectedSources.indexOf(cmd) !== -1) {
            executable.disconnectSource(cmd);
        }
        executable.connectSource(cmd);
    }

    Timer {
        id: pollTimer
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: readCache()
    }

    preferredRepresentation: compactRepresentation

    compactRepresentation: MouseArea {
        id: compactMouse
        Layout.preferredWidth: root.cacheExists ? compactGrid.implicitWidth : 0
        Layout.preferredHeight: root.cacheExists ? compactGrid.implicitHeight : 0
        visible: root.cacheExists
        onClicked: root.expanded = !root.expanded

        GridLayout {
            id: compactGrid
            anchors.centerIn: parent
            columns: 2
            columnSpacing: 2
            rowSpacing: 0
            opacity: root.isStale ? 0.5 : 1.0

            PlasmaComponents.Label {
                text: root.isStale ? "⚠" : root.glyphForPct(root.s5h)
                color: root.claudeOrange
                font.pixelSize: 11
                Layout.rowSpan: 2
                Layout.alignment: Qt.AlignVCenter
            }

            PlasmaComponents.Label {
                text: "5h:" + root.s5h + "%"
                color: root.colorForPct(root.s5h)
                font.pixelSize: 11
            }

            PlasmaComponents.Label {
                text: "7d:" + root.s7d + "%"
                color: root.colorForPct(root.s7d)
                font.pixelSize: 11
            }
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: 200
        Layout.preferredHeight: implicitHeight
        spacing: 4

        PlasmaComponents.Label {
            text: "Claude Code Quota"
            font.bold: true
            font.pixelSize: 13
            color: root.claudeOrange
            Layout.bottomMargin: 2
        }

        PlasmaComponents.Label {
            text: "5h: " + root.s5h + "%  ⟳ " + root.fmtReset(root.sr)
            color: root.colorForPct(root.s5h)
            font.pixelSize: 12
        }

        PlasmaComponents.Label {
            text: "7d: " + root.s7d + "%  ⟳ " + root.fmtReset(root.wr)
            color: root.colorForPct(root.s7d)
            font.pixelSize: 12
        }

        PlasmaComponents.Label {
            text: "Status: " + root.st
            font.pixelSize: 11
            opacity: 0.6
        }

        PlasmaComponents.Label {
            visible: root.isStale
            text: "⚠ Data may be stale"
            color: root.warningAmber
            font.pixelSize: 11
        }
    }
}

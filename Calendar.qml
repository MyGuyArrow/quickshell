import QtQuick
import QtQuick.Layouts

// Month grid. Tokens are injected by the parent so it follows the island's theme.
ColumnLayout {
    id: cal

    property color accent: "#7aa2f7"
    property color accentText: "#ffffff"
    property color fg: "#ffffff"
    property color dim: "#a1a1aa"
    property string fam: "SF Pro Text"
    property string icons: "JetBrainsMono Nerd Font"
    property string chevL: "‹"
    property string chevR: "›"

    // Injected by the parent from its SystemClock, never read from the process
    // clock: a shell that runs for days would otherwise circle the day it started.
    property date today: new Date()
    property date shown: today

    // Monday-first offset of the 1st of the shown month, and only as many rows
    // as the month actually needs.
    readonly property int offset: (new Date(shown.getFullYear(), shown.getMonth(), 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()

    spacing: 8

    function shift(months) {
        shown = new Date(shown.getFullYear(), shown.getMonth() + months, 1)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            Layout.fillWidth: true
            text: Qt.formatDate(cal.shown, "MMMM yyyy")
            color: cal.fg
            font.family: cal.fam
            font.pixelSize: 13
            font.weight: Font.DemiBold
            MouseArea { anchors.fill: parent; onClicked: cal.shown = new Date() }
        }

        Text {
            text: cal.chevL; color: cal.accent; font.family: cal.icons; font.pixelSize: 18
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cal.shift(-1) }
        }
        Text {
            text: cal.chevR; color: cal.accent; font.family: cal.icons; font.pixelSize: 18
            Layout.leftMargin: 8
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cal.shift(1) }
        }
    }

    Grid {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 2

        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]
            Text {
                required property string modelData
                width: parent.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: cal.dim
                font.family: cal.fam
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        Repeater {
            model: 7 * Math.ceil((cal.offset + cal.daysInMonth) / 7)

            Item {
                id: cell
                required property int index

                readonly property date day: new Date(cal.shown.getFullYear(), cal.shown.getMonth(), index - cal.offset + 1)
                readonly property bool inMonth: day.getMonth() === cal.shown.getMonth()
                readonly property bool isToday: day.toDateString() === cal.today.toDateString()

                width: parent.width / 7
                height: 26

                Rectangle {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    radius: 12
                    color: cell.isToday ? cal.accent : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.day.getDate()
                    color: cell.isToday ? cal.accentText : (cell.inMonth ? cal.fg : cal.dim)
                    font.family: cal.fam
                    font.pixelSize: 11
                    font.weight: cell.isToday ? Font.Bold : Font.Normal
                }
            }
        }
    }
}

// A raster cropped to a rounded rectangle.
//
// Qt clipping is rectangular: a rounded Rectangle with clip:true still shows
// square image corners, which is what the island's album art used to do. The
// image has to be masked instead.
import QtQuick
import QtQuick.Effects

Item {
    id: ri

    property alias source: img.source
    property alias status: img.status
    property real cornerRadius: 10

    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.round(ri.width * 2), Math.round(ri.height * 2))
        asynchronous: true
        visible: false
        layer.enabled: true
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: ri.cornerRadius; color: "white" }
    }

    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: mask
        visible: img.status === Image.Ready
    }
}

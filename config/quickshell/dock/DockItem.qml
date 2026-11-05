import QtQuick
import Quickshell.Widgets
import qs.core

// One dock slot: an app icon with a running dot, or a thin separator between
// favorites and other running apps.
Item {
    id: root

    required property var dockItem
    required property int iconSize
    required property real scaleFactor
    signal activated()

    readonly property bool separator: dockItem.separator === true
    readonly property int dotSize: Theme.scaledSize(4)
    readonly property int dotGap: Theme.scaledSize(3)

    width: separator ? Theme.scaledSize(9) : Math.round(iconSize * scaleFactor)
    height: parent ? parent.height : iconSize

    Behavior on width {
        NumberAnimation { duration: Theme.animationFast }
    }

    Rectangle {
        visible: root.separator
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.dotSize + root.dotGap
        width: Theme.scaledSize(1)
        height: Math.round(root.iconSize * 0.8)
        color: Theme.withAlpha(Theme.textStrong, 25)
    }

    IconImage {
        id: icon

        visible: !root.separator
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.dotSize + root.dotGap
        implicitSize: root.width
        source: root.separator ? "" : root.dockItem.icon
        asynchronous: true
    }

    Rectangle {
        visible: !root.separator && root.dockItem.windowId !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.dotSize
        height: root.dotSize
        radius: root.dotSize / 2
        color: Theme.textStrong
    }

    MouseArea {
        visible: !root.separator
        anchors.fill: icon
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}

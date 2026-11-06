import QtQuick
import Quickshell.Widgets
import qs.core

// One dock slot: an app icon with a running dot, or a thin separator between
// pinned and other running apps. `edge` is the screen edge the dock sits on:
// the icon grows away from it and the running dot stays next to it. The icon
// is drawn once at its largest size and magnified with a scale transform, so
// hovering never re-rasterizes it.
Item {
    id: root

    required property var dockItem
    required property int iconSize
    required property real scaleFactor
    required property int crossSize
    required property int maxIconSize
    property string edge: "bottom"
    signal activated()
    signal menuRequested(real x, real y)

    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool separator: dockItem.separator === true
    readonly property int dotSize: Theme.scaledSize(4)
    readonly property int dotGap: Theme.scaledSize(3)
    readonly property int edgeInset: root.dotSize + root.dotGap
    readonly property real mainSize: separator ? Theme.scaledSize(9) : iconSize * scaleFactor

    width: vertical ? crossSize : mainSize
    height: vertical ? mainSize : crossSize

    // Separator: a thin line across the dock.
    Rectangle {
        visible: root.separator
        anchors.centerIn: parent
        width: root.vertical ? Math.round(root.iconSize * 0.8) : Theme.scaledSize(1)
        height: root.vertical ? Theme.scaledSize(1) : Math.round(root.iconSize * 0.8)
        color: Theme.withAlpha(Theme.textStrong, 25)
    }

    IconImage {
        id: icon

        visible: !root.separator
        implicitSize: root.maxIconSize
        source: root.separator ? "" : root.dockItem.icon
        asynchronous: true
        smooth: true
        // Scaled about the side facing the screen edge, so the icon keeps its
        // distance from the running dot while it grows.
        scale: root.mainSize / root.maxIconSize
        transformOrigin: root.edge === "left" ? Item.Left : root.edge === "right" ? Item.Right
            : root.edge === "top" ? Item.Top : Item.Bottom
        x: root.edge === "left" ? root.edgeInset
            : root.edge === "right" ? root.width - root.edgeInset - width
            : (root.width - width) / 2
        y: root.edge === "top" ? root.edgeInset
            : root.edge === "bottom" ? root.height - root.edgeInset - height
            : (root.height - height) / 2
    }

    Rectangle {
        visible: !root.separator && root.dockItem.windowId !== ""
        width: root.dotSize
        height: root.dotSize
        radius: root.dotSize / 2
        color: Theme.textStrong
        x: root.edge === "left" ? 0
            : root.edge === "right" ? root.width - width
            : (root.width - width) / 2
        y: root.edge === "top" ? 0
            : root.edge === "bottom" ? root.height - height
            : (root.height - height) / 2
    }

    MouseArea {
        visible: !root.separator
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                const p = mapToItem(null, mouse.x, mouse.y);
                root.menuRequested(p.x, p.y);
            } else {
                root.activated();
            }
        }
    }
}

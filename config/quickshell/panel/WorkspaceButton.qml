import QtQuick
import QtQuick.Layouts
import qs.core

Rectangle {
    id: root

    required property string label
    required property bool selected
    required property bool occupied
    // Soft style: the active tag is a wider accent pill, occupied tags use the
    // main text color, and empty tags fade to the faint text color.
    property bool soft: false
    // macOS layout: a small dot, filled for the current tag and dimmed for
    // empty ones.
    property bool dot: false
    // True draws every tag number in the strong text color (macOS layout);
    // the current tag keeps its accent border.
    property bool whiteText: false
    // False keeps the current tag at the regular weight (macOS layout).
    property bool boldSelected: true
    // False draws the current tag with its border only, no background.
    property bool fillSelected: true
    signal clicked()

    Layout.preferredWidth: dot ? Theme.scaledSize(14) : soft && selected ? Theme.workspaceButtonSize * 2 : Theme.workspaceButtonSize
    Layout.preferredHeight: Theme.workspaceButtonSize
    radius: soft ? Theme.pillRadius : Theme.smallRadius
    color: dot ? Theme.transparent
        : selected && !fillSelected ? Theme.transparent
        : soft ? (selected ? Theme.accent
            : workspaceMouse.containsMouse ? Theme.accentSoft : Theme.transparent)
        : selected ? Theme.controlSelectedFill
        : workspaceMouse.containsMouse ? Theme.controlHoverFill : Theme.transparent
    border.color: selected ? Theme.controlSelectedBorder
        : workspaceMouse.containsMouse ? Theme.controlHoverBorder : Theme.transparent
    border.width: !dot && !soft && (selected || workspaceMouse.containsMouse) ? Theme.pillBorderWidth : 0

    Behavior on Layout.preferredWidth {
        NumberAnimation { duration: Theme.animationNormal }
    }

    Rectangle {
        anchors.centerIn: parent
        visible: root.dot
        width: Theme.scaledSize(root.selected ? 7 : 5)
        height: width
        radius: width / 2
        color: root.selected ? Theme.textStrong
            : root.occupied || workspaceMouse.containsMouse ? Theme.textSecondary : Theme.textFaint
    }

    Text {
        anchors.centerIn: parent
        visible: !root.dot
        text: root.label
        color: root.whiteText ? Theme.textStrong
            : root.soft ? (root.selected ? Theme.accentText
                : root.occupied || workspaceMouse.containsMouse ? Theme.text : Theme.textFaint)
            : root.selected ? Theme.controlSelectedText
            : workspaceMouse.containsMouse ? Theme.controlHoverText : Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.panelFontSize
        font.weight: root.soft ? (root.selected ? Theme.styleFontWeightStrong : Theme.styleFontWeight)
            : (root.selected && root.boldSelected ? Font.Bold : Font.Normal)
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: workspaceMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

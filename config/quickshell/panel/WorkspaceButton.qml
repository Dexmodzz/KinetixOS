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
    signal clicked()

    Layout.preferredWidth: soft && selected ? Theme.workspaceButtonSize * 2 : Theme.workspaceButtonSize
    Layout.preferredHeight: Theme.workspaceButtonSize
    radius: soft ? Theme.pillRadius : Theme.smallRadius
    color: soft ? (selected ? Theme.accent
            : workspaceMouse.containsMouse ? Theme.accentSoft : Theme.transparent)
        : selected ? Theme.controlSelectedFill
        : workspaceMouse.containsMouse ? Theme.controlHoverFill : Theme.transparent
    border.color: selected ? Theme.controlSelectedBorder
        : workspaceMouse.containsMouse ? Theme.controlHoverBorder : Theme.transparent
    border.width: !soft && (selected || workspaceMouse.containsMouse) ? Theme.pillBorderWidth : 0

    Behavior on Layout.preferredWidth {
        NumberAnimation { duration: Theme.animationNormal }
    }

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.soft ? (root.selected ? Theme.accentText
                : root.occupied || workspaceMouse.containsMouse ? Theme.text : Theme.textFaint)
            : root.selected ? Theme.controlSelectedText
            : workspaceMouse.containsMouse ? Theme.controlHoverText : Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.panelFontSize
        font.weight: root.soft ? (root.selected ? Theme.styleFontWeightStrong : Theme.styleFontWeight)
            : (root.selected ? Font.Bold : Font.Normal)
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

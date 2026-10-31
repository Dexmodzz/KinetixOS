import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.core

Rectangle {
    id: root

    required property int index
    required property var modelData
    required property bool selected
    required property var launcherModel

    height: Theme.scaledSize(58)
    radius: Theme.largeSurfaceCardRadius
    color: Theme.softStyle
        ? (selected ? Theme.accentSoft : resultMouse.containsMouse ? Theme.menuHoverBackground : Theme.transparent)
        : selected ? Theme.menuSelectedBackground : resultMouse.containsMouse ? Theme.menuHoverBackground : Theme.transparent
    border.color: selected && !Theme.softStyle ? Theme.controlSelectedBorder : Theme.transparent
    border.width: Theme.softStyle ? 0 : Theme.controlBorderWidth

    MouseArea {
        id: resultMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.launcherModel.launchApp(root.modelData)
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXxl

        Rectangle {
            Layout.preferredWidth: 3
            Layout.preferredHeight: 34
            visible: root.selected && !Theme.softStyle
            color: Theme.accentSecondary
            radius: 2
        }

        // Soft style frames the icon in a small tile; classic shows it bare.
        Rectangle {
            Layout.preferredWidth: Theme.iconSize
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.radius
            color: Theme.softStyle ? (root.selected ? Theme.accentSoft : Theme.chip) : Theme.transparent

            IconImage {
                anchors.centerIn: parent
                implicitSize: Theme.softStyle ? Theme.iconSize - Theme.spacingLg : Theme.iconSize
                source: Icons.launcherIcon(root.modelData.icon)
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: Theme.tightSpacing

            Text {
                width: parent.width
                text: root.modelData.name
                color: Theme.softStyle ? Theme.textStrong
                    : root.selected ? Theme.menuSelectedText : Theme.menuText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
                font.weight: Theme.softStyle ? Theme.styleFontWeightStrong
                    : root.selected ? Font.Bold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: {
                    const detail = root.modelData.generic.length > 0 ? root.modelData.generic : root.modelData.comment;
                    const category = root.launcherModel.categoryLabel(root.modelData.primaryCategory);

                    if (detail.length > 0) {
                        return detail + (Theme.softStyle ? " · " : "  -  ") + category;
                    }

                    return category;
                }
                color: Theme.menuMutedText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }

        UiText {
            visible: Theme.softStyle && root.selected
            text: "⏎"
            color: Theme.accent
            font.pixelSize: Theme.bodyFontSize
        }
    }
}

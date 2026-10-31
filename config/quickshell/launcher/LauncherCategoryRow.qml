import QtQuick
import QtQuick.Layouts
import qs.core

pragma ComponentBehavior: Bound

Flickable {
    id: root

    required property var launcherModel

    contentWidth: launcherCategoryRow.width
    contentHeight: height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    RowLayout {
        id: launcherCategoryRow

        height: parent.height
        spacing: Theme.listSpacing + Theme.compactSpacing

        Repeater {
            model: root.launcherModel.categories

            delegate: Rectangle {
                id: categoryDelegate

                required property var modelData

                Layout.preferredHeight: Theme.chipHeight
                Layout.preferredWidth: launcherCategoryLabel.width + 22
                readonly property bool active: root.launcherModel.category === categoryDelegate.modelData.id

                radius: Theme.softStyle ? Theme.pillRadius : Theme.controlRadius
                color: Theme.softStyle
                    ? (active ? Theme.accent : launcherCategoryMouse.containsMouse ? Theme.borderSubtle : Theme.accentSoft)
                    : active ? Theme.controlSelectedFill
                    : launcherCategoryMouse.containsMouse ? Theme.controlHoverFill : Theme.controlNormalFill
                border.color: Theme.softStyle ? Theme.transparent
                    : active ? Theme.controlSelectedBorder
                    : launcherCategoryMouse.containsMouse ? Theme.controlHoverBorder : Theme.controlNormalBorder
                border.width: Theme.softStyle ? 0 : Theme.controlBorderWidth

                Text {
                    id: launcherCategoryLabel

                    anchors.centerIn: parent
                    text: categoryDelegate.modelData.label + " " + categoryDelegate.modelData.count
                    color: Theme.softStyle
                        ? (categoryDelegate.active ? Theme.accentText : Theme.text)
                        : categoryDelegate.active ? Theme.controlSelectedText : Theme.controlNormalText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                    font.bold: root.launcherModel.category === categoryDelegate.modelData.id
                }

                MouseArea {
                    id: launcherCategoryMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launcherModel.setCategory(categoryDelegate.modelData.id)
                }
            }
        }
    }
}

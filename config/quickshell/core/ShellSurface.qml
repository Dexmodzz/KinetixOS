import QtQuick
import qs.core

Rectangle {
    id: root

    default property alias content: body.data
    property alias contentItem: body
    property int margin: Theme.popupPadding
    // A window dwm manages has a dwm border around it. The compositor rounds
    // such windows, border included, so the surface itself stays square.
    property bool managedWindow: false

    opacity: 1.0
    color: Theme.popupBackground
    border.color: Theme.popupBorder
    border.width: Theme.controlBorderWidth
    radius: managedWindow ? 0 : Theme.popupRadius

    PillShadow { cornerRadius: root.radius }

    Item {
        id: body

        anchors.fill: parent
        anchors.margins: root.margin
    }
}

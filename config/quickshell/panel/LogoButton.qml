import QtQuick
import QtQuick.Layouts
import qs.core

PanelPill {
    id: root

    signal activated

    Layout.preferredWidth: Theme.pillHeight
    Layout.preferredHeight: Theme.pillHeight
    hovered: logoMouse.containsMouse

    // Soft style: a "K" on a small accent tile instead of the color logo.
    Rectangle {
        anchors.centerIn: parent
        visible: Theme.styleBarIslands
        width: Theme.compactWidgetSize
        height: Theme.compactWidgetSize
        radius: Theme.logoRadius
        color: Theme.accent

        UiText {
            anchors.centerIn: parent
            text: "K"
            color: Theme.accentText
            font.pixelSize: Theme.panelFontSize
            font.weight: Theme.styleFontWeightStrong
        }
    }

    Image {
        id: logoImage

        visible: !Theme.styleBarIslands
        anchors.centerIn: parent
        width: Theme.scaledSize(24)
        height: Theme.scaledSize(25.2)
        source: Qt.resolvedUrl("../assets/kinetixos_logo.png")
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
    }

    UiText {
        anchors.centerIn: parent
        visible: !Theme.styleBarIslands && logoImage.status === Image.Error
        text: "CTT"
        color: Theme.accent
        font.pixelSize: Theme.tinyFontSize
        font.bold: true
    }

    MouseArea {
        id: logoMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}

import QtQuick
import QtQuick.Layouts
import qs.core

PanelPill {
    id: root

    signal activated
    // macOS layout: a plain apple glyph instead of the KinetixOS logo.
    property bool apple: false

    Layout.preferredWidth: Theme.pillHeight
    Layout.preferredHeight: Theme.pillHeight
    hovered: logoMouse.containsMouse
    radius: Theme.styleBarIslands ? Theme.logoRadius : Theme.pillRadius

    IconText {
        anchors.centerIn: parent
        visible: root.apple
        text: "\uf179"
        color: Theme.textStrong
        font.pixelSize: Theme.scaledFontSize(17, 10)
    }

    Image {
        id: logoImage

        anchors.centerIn: parent
        visible: !root.apple
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
        visible: !root.apple && logoImage.status === Image.Error
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

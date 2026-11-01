import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

pragma ComponentBehavior: Bound

// qmllint disable uncreatable-type
PanelWindow {
    id: root

    signal popupRequested(var panelWindow, string popupId)

    function batteryIcon(percent, status) {
        if (status.toLowerCase() === "charging") {
            return "󰂄";
        }

        if (percent >= 90) return "󰁹";
        if (percent >= 80) return "󰂂";
        if (percent >= 70) return "󰂁";
        if (percent >= 60) return "󰂀";
        if (percent >= 50) return "󰁿";
        if (percent >= 40) return "󰁾";
        if (percent >= 30) return "󰁽";
        if (percent >= 20) return "󰁼";
        if (percent >= 10) return "󰁻";
        return "󰂎";
    }

    property var desktopUpdateModel: null
    required property var state
    required property var clock
    required property var networkModel
    required property var controlsModel
    required property var bluetoothModel
    required property var controlCenterModel
    required property var panelSettingsModel
    required property var powerModel
    required property var powerMenuModel
    required property bool primaryPanel

    readonly property bool islands: Theme.styleBarIslands

    implicitHeight: Theme.panelWindowHeight
    // Always create the window with a transparent color: Quickshell picks an
    // alpha-capable surface only at creation, and the shell can start before
    // Picom. The backdrop below paints the solid bar when gaps must not show.
    color: Theme.transparent
    exclusiveZone: Theme.panelWindowHeight
    aboveWindows: root.state.fullscreenMonitorIndexes.indexOf(
        root.state.screenIndex(root.screen)) === -1

    anchors {
        top: true
        left: true
        right: true
    }

    Rectangle {
        anchors.fill: parent
        visible: !Theme.barIslandsTransparent
        color: Theme.barBackground
    }

    Rectangle {
        id: island

        anchors.fill: parent
        anchors.leftMargin: Theme.panelEdgeMargin
        anchors.rightMargin: Theme.panelEdgeMargin
        anchors.topMargin: Theme.panelMargin
        anchors.bottomMargin: 0
        opacity: 1.0
        color: root.islands ? Theme.transparent : Theme.barBackground
        border.color: Theme.border
        border.width: root.islands ? 0 : Theme.pillBorderWidth
        radius: Theme.barRadius

        PillShadow { cornerRadius: island.radius }

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupRequested(root, "")
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.islands ? 0 : Theme.panelGap
            anchors.rightMargin: root.islands ? 0 : Theme.panelGap
            spacing: Theme.panelGap

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0

                PanelIsland {
                    anchors.left: parent.left
                    width: Math.min(leftRow.width + Theme.islandPadding * 2, parent.width)
                    height: parent.height
                }

                RowLayout {
                    id: leftRow
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.islandPadding
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - Theme.islandPadding * 2)
                    height: parent.height
                    spacing: Theme.panelGap

                    LogoButton {
                        id: logoButton
                        onActivated: {
                            root.popupRequested(root, "controlcenter");
                            root.controlCenterModel.toggle();
                        }
                    }

                    PanelPill {
                        visible: root.panelSettingsModel.widgetEnabled("workspaces")
                        Layout.preferredWidth: workspaceRow.implicitWidth + 8
                        Layout.preferredHeight: Theme.pillHeight

                        RowLayout {
                            id: workspaceRow

                            anchors.centerIn: parent
                            spacing: 1

                            Repeater {
                                model: root.state.workspaceIndexes(root.screen)

                                delegate: WorkspaceButton {
                                    required property int modelData

                                    soft: root.islands
                                    label: root.state.workspaceNames[modelData]
                                    selected: modelData === root.state.currentWorkspaceForScreen(root.screen)
                                    occupied: root.state.workspaceOccupied(modelData)
                                    onClicked: root.state.switchWorkspaceForScreen(root.screen, modelData)
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: root.islands
                        Layout.preferredWidth: Theme.pillBorderWidth
                        Layout.preferredHeight: Theme.panelIconFontSize
                        color: Theme.borderSubtle
                    }

                    PanelPill {
                        Layout.preferredWidth: Math.min(activeTitle.implicitWidth + Theme.pillHorizontalPadding * 2, 260)
                        Layout.preferredHeight: Theme.pillHeight
                        outlined: !root.islands

                        UiText {
                            id: activeTitle
                            anchors.fill: parent
                            anchors.leftMargin: Theme.pillHorizontalPadding
                            anchors.rightMargin: Theme.pillHorizontalPadding
                            text: root.state.activeWindowTitle
                            color: root.islands ? Theme.textSecondary : Theme.text
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                }
            }

            PanelPill {
                Layout.preferredWidth: (root.islands ? softClock.implicitWidth : clockLabel.implicitWidth)
                    + Theme.pillHorizontalPadding * 2 + Theme.islandPadding * 2
                Layout.preferredHeight: root.islands ? Theme.panelHeight : Theme.pillHeight
                outlined: !root.islands

                PanelIsland {
                    anchors.fill: parent
                    z: -1
                }

                UiText {
                    id: clockLabel

                    anchors.centerIn: parent
                    visible: !root.islands
                    text: root.clock.panelText
                    color: Theme.textStrong
                    font.bold: true
                }

                Row {
                    id: softClock

                    anchors.centerIn: parent
                    visible: root.islands
                    spacing: Theme.spacingMd

                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.clock.dateText
                        color: Theme.textStrong
                        font.weight: Theme.styleFontWeightStrong
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.spacingSm
                        height: Theme.spacingSm
                        radius: width / 2
                        color: Theme.accent
                    }

                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.clock.timeText
                        color: Theme.textStrong
                        font.weight: Theme.styleFontWeightStrong
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0

                PanelIsland {
                    anchors.right: parent.right
                    width: Math.min(rightRow.width + Theme.islandPadding * 2, parent.width)
                    height: parent.height
                }

                RowLayout {
                    id: rightRow
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.islandPadding
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - Theme.islandPadding * 2)
                    height: parent.height
                    spacing: Theme.panelGap

                    Repeater {
                        model: root.state.statusSegments

                        delegate: PanelPill {
                            required property string modelData
                            Layout.preferredWidth: statusLabel.implicitWidth + Theme.pillHorizontalPadding * 2
                            Layout.preferredHeight: Theme.pillHeight
                            outlined: true

                            UiText {
                                id: statusLabel
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: Theme.text
                            }
                        }
                    }

                    ShellButton {
                        objectName: "desktopUpdateIndicator"
                        visible: root.desktopUpdateModel !== null && (root.desktopUpdateModel.active
                            || ["failed", "interrupted", "restart-required"].indexOf(root.desktopUpdateModel.status.state) >= 0
                            || (root.desktopUpdateModel.status.state === "current" && !!root.desktopUpdateModel.status.operation))
                        label: !root.desktopUpdateModel ? "" : root.desktopUpdateModel.active ? "Updating..."
                            : root.desktopUpdateModel.status.state === "current" ? "Updated"
                            : root.desktopUpdateModel.status.state === "restart-required" ? "Logout required" : "Update needs attention"
                        enabled: root.desktopUpdateModel !== null && !root.desktopUpdateModel.progressPending
                        onActivated: root.desktopUpdateModel.showProgress()
                    }

                    RunningAppsArea { desktopState: root.state }

                    Loader {
                        active: root.primaryPanel
                        sourceComponent: TrayArea {}
                    }

                    PanelPill {
                        id: batteryPill
                        visible: root.powerModel.batteryAvailable
                        Layout.preferredWidth: batteryRow.implicitWidth + Theme.compactWidgetHorizontalPadding * 2
                        Layout.preferredHeight: Theme.compactWidgetSize
                        hovered: batteryMouse.containsMouse

                        RowLayout {
                            id: batteryRow
                            anchors.centerIn: parent
                            spacing: Theme.compactSpacing

                            IconText {
                                text: root.batteryIcon(root.powerModel.batteryPercent, root.powerModel.batteryStatus)
                                color: Theme.textStrong
                                font.pixelSize: Theme.scaledFontSize(14 * 1.1, 8)
                            }

                            UiText {
                                text: root.powerModel.batteryPercent.toString() + "%"
                                color: Theme.textStrong
                                font.pixelSize: Theme.panelFontSize
                            }
                        }

                        MouseArea {
                            id: batteryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }

                    PanelPill {
                        visible: root.panelSettingsModel.widgetEnabled("bluetooth")
                        Layout.preferredWidth: bluetoothRow.implicitWidth + Theme.compactWidgetHorizontalPadding * 2
                        Layout.preferredHeight: Theme.compactWidgetSize
                        active: root.bluetoothModel.visible
                        hovered: bluetoothMouse.containsMouse

                        RowLayout {
                            id: bluetoothRow
                            anchors.centerIn: parent
                            spacing: Theme.compactSpacing

                            IconText {
                                text: "󰂯"
                                color: Theme.textStrong
                                font.pixelSize: Theme.scaledFontSize(14 * 0.9, 8)
                            }
                        }

                        MouseArea {
                            id: bluetoothMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.popupRequested(root, "bluetooth");
                                root.bluetoothModel.toggle();
                            }
                        }
                    }

                    PanelPill {
                        visible: root.panelSettingsModel.widgetEnabled("network")
                        Layout.preferredWidth: networkRow.implicitWidth + Theme.networkWidgetHorizontalPadding * 2
                        Layout.preferredHeight: Theme.compactWidgetSize
                        active: root.networkModel.visible
                        hovered: networkMouse.containsMouse

                        RowLayout {
                            id: networkRow
                            anchors.centerIn: parent
                            spacing: Theme.compactSpacing

                            IconText {
                                text: root.networkModel.statusText.indexOf("offline") >= 0
                                    || root.networkModel.statusText.indexOf("unavailable") >= 0 ? "󰤭" : "󰤨"
                                color: Theme.textStrong
                                font.pixelSize: Theme.scaledFontSize(14 * 1.2, 8)
                            }
                        }

                        MouseArea {
                            id: networkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.popupRequested(root, "network");
                                root.networkModel.toggle();
                            }
                        }
                    }

                    PanelPill {
                        visible: root.panelSettingsModel.widgetEnabled("volume")
                        Layout.preferredWidth: volumeRow.implicitWidth + Theme.compactWidgetHorizontalPadding * 2
                        Layout.preferredHeight: Theme.compactWidgetSize
                        active: root.controlsModel.visible
                        hovered: controlsMouse.containsMouse

                        RowLayout {
                            id: volumeRow
                            anchors.centerIn: parent
                            spacing: Theme.compactSpacing

                            IconText {
                                text: root.controlsModel.volumeMuted ? "󰝟" : "󰕾"
                                color: Theme.textStrong
                                font.pixelSize: Theme.scaledFontSize(14 * 1.5, 8)
                            }

                            UiText {
                                visible: root.controlsModel.volumeText !== "VOL unavailable"
                                text: root.controlsModel.volumePercent.toString() + "%"
                                color: Theme.textStrong
                                font.pixelSize: Theme.panelFontSize
                            }
                        }

                        MouseArea {
                            id: controlsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.popupRequested(root, "controls");
                                root.controlsModel.toggle();
                            }
                            onWheel: function(wheel) {
                                if (wheel.angleDelta.y > 0) {
                                    root.controlsModel.volumeUp();
                                } else if (wheel.angleDelta.y < 0) {
                                    root.controlsModel.volumeDown();
                                }
                                wheel.accepted = true;
                            }
                        }
                    }

                    PanelPill {
                        visible: root.panelSettingsModel.widgetEnabled("power")
                        Layout.preferredWidth: Theme.pillHeight
                        Layout.preferredHeight: Theme.pillHeight
                        active: root.powerMenuModel.visible
                        hovered: powerMouse.containsMouse
                        color: root.islands ? Theme.accentSoft
                            : active ? Theme.controlSelectedFill
                            : hovered ? Theme.controlHoverFill : Theme.transparent
                        radius: root.islands ? Theme.radius : Theme.pillRadius

                        IconText {
                            anchors.centerIn: parent
                            text: "󰐥"
                            color: root.islands ? Theme.accent : Theme.textStrong
                            font.pixelSize: Theme.scaledFontSize(14 * 1.08, 8)
                        }

                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.popupRequested(root, "power");
                                root.powerMenuModel.toggle("panel");
                            }
                        }
                    }
                }
            }
        }
    }

    PanelTooltip {
        visible: logoButton.hovered
        anchorWindow: root
        anchorItem: logoButton
        label: "Control Center"
        anchorY: Theme.panelWindowHeight
    }

    PanelTooltip {
        visible: root.powerModel.batteryAvailable && batteryMouse.containsMouse
        anchorWindow: root
        anchorItem: batteryPill
        label: root.powerModel.batteryPercent.toString() + "% - " + root.powerModel.batteryStatus
        anchorY: Theme.panelWindowHeight
        rightAligned: true
    }

    PanelTooltip {
        visible: bluetoothMouse.containsMouse
        anchorWindow: root
        anchorItem: bluetoothMouse
        label: root.bluetoothModel.statusText
        anchorY: Theme.panelWindowHeight
        rightAligned: true
    }

    PanelTooltip {
        visible: networkMouse.containsMouse
        anchorWindow: root
        anchorItem: networkMouse
        label: root.networkModel.statusText
        anchorY: Theme.panelWindowHeight
        rightAligned: true
    }

    PanelTooltip {
        visible: controlsMouse.containsMouse
        anchorWindow: root
        anchorItem: controlsMouse
        label: root.controlsModel.volumeDisplayText
        anchorY: Theme.panelWindowHeight
        rightAligned: true
    }

    PanelTooltip {
        visible: powerMouse.containsMouse
        anchorWindow: root
        anchorItem: powerMouse
        label: "Power"
        anchorY: Theme.panelWindowHeight
        rightAligned: true
    }
}

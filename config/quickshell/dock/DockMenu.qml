import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.core

pragma ComponentBehavior: Bound

// Dock context menu: actions for the clicked app, the open apps, a scrolling
// list of installed apps to pin or unpin, the dock edge and a hide switch.
// No text input: X11 popups that grab the pointer get no keyboard focus.
// Like ClickAwayPopup, the window is a transparent full-screen surface below
// the bar: X11 does not dismiss popups on an outside click, so a click outside
// the card closes the menu here.
// qmllint disable uncreatable-type
PopupWindow {
    id: root

    required property var dockWindow
    required property var desktopState
    required property var dockSettings
    property string edge: "bottom"
    property var runningItems: []
    property var targetItem: null
    property real anchorX: 0
    property real anchorY: 0
    property bool trashFull: false
    property int trashCount: 0
    // Emptying the Trash is permanent, so it takes a second, explicit click.
    property bool confirmEmpty: false
    // Quitting an app with windows on another desktop asks first: those
    // windows are out of sight.
    property bool confirmQuit: false
    readonly property int currentDesktop: root.desktopState.currentWorkspaceForScreen(
        root.dockWindow ? root.dockWindow.screen : null)
    // One-based numbers of the other desktops the clicked app has windows on.
    readonly property var otherDesktops: {
        if (!root.hasTarget || !root.targetItem.appClass) return [];
        const desktops = root.desktopState.appDesktops[root.targetItem.appClass] || [];
        return desktops.filter(desktop => desktop !== root.currentDesktop).map(desktop => desktop + 1);
    }

    function quitTarget() {
        root.desktopState.closeApp(root.targetItem.windowId);
        root.close();
    }
    signal launchRequested(string id)
    signal openTrashRequested()
    signal emptyTrashRequested()

    readonly property int gap: Theme.scaledSize(10)
    readonly property int rowHeight: Theme.scaledSize(30)
    readonly property int smallIcon: Theme.scaledSize(20)
    readonly property bool hasTarget: root.targetItem !== null && root.targetItem.id !== undefined
    readonly property bool targetIsTrash: root.hasTarget && root.targetItem.trash === true
    // One row per app name: some packages ship two entries with the same name.
    readonly property var allApps: {
        const byName = {};
        for (const entry of DesktopEntries.applications.values) {
            if (!entry.noDisplay && !byName[String(entry.name)]) byName[String(entry.name)] = entry;
        }
        const list = Object.values(byName);
        list.sort((a, b) => String(a.name).localeCompare(String(b.name)));
        return list;
    }

    function close() {
        root.visible = false;
    }

    // The pinned ID standing for this app: its own, or a pinned entry with
    // the same name (a hidden duplicate the list does not show).
    function pinnedIdFor(entry) {
        if (root.dockSettings.isPinned(entry.id)) return entry.id;
        for (const id of root.dockSettings.apps) {
            const pinned = DesktopEntries.byId(id);
            if (pinned && pinned.name === entry.name) return id;
        }
        return "";
    }

    function togglePinnedEntry(entry) {
        const pinnedId = root.pinnedIdFor(entry);
        if (pinnedId.length > 0)
            root.dockSettings.setPinned(pinnedId, false);
        else
            root.dockSettings.setPinned(entry.id, true);
    }

    // Screen geometry: the dock window's origin follows from its edge, and
    // the menu surface covers the screen below the bar.
    readonly property var dockScreen: root.dockWindow ? root.dockWindow.screen : null
    readonly property int screenWidth: root.dockScreen ? root.dockScreen.width : 0
    readonly property int screenHeight: root.dockScreen ? root.dockScreen.height : 0
    readonly property int topOffset: Theme.panelWindowHeight
    readonly property int dockX: root.edge === "right" ? root.screenWidth - root.dockWindow.width : 0
    readonly property int dockY: root.edge === "bottom" ? root.screenHeight - root.dockWindow.height
        : root.edge === "top" ? Theme.panelWindowHeight : 0
    // The click, in menu-surface coordinates.
    readonly property real clickX: root.dockX + root.anchorX
    readonly property real clickY: root.dockY + root.anchorY - root.topOffset
    readonly property int cardWidth: Theme.scaledSize(320)

    anchor.window: root.dockWindow
    anchor.rect.x: -root.dockX
    anchor.rect.y: root.topOffset - root.dockY
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top | Edges.Left // qmllint disable missing-type
    anchor.gravity: Edges.Bottom | Edges.Right // qmllint disable missing-type
    anchor.adjustment: PopupAdjustment.None // qmllint disable missing-type

    grabFocus: true
    color: Theme.transparent
    implicitWidth: root.screenWidth
    implicitHeight: Math.max(0, root.screenHeight - root.topOffset)

    onVisibleChanged: {
        root.confirmEmpty = false;
        root.confirmQuit = false;
        if (visible)
            appList.positionViewAtBeginning();
    }

    // A small app row: icon, name, optional trailing mark.
    component AppRow: Rectangle {
        id: appRow

        required property string iconSource
        required property string name
        property string mark: ""
        property bool markActive: false
        signal clicked()
        signal markClicked()

        Layout.fillWidth: true
        implicitHeight: root.rowHeight
        radius: Theme.controlRadius
        color: rowMouse.containsMouse ? Theme.menuHoverBackground : Theme.transparent

        MouseArea {
            id: rowMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: appRow.clicked()
        }

        IconImage {
            id: rowIcon

            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingMd
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: root.smallIcon
            source: appRow.iconSource
            asynchronous: true
        }

        UiText {
            anchors.left: rowIcon.right
            anchors.leftMargin: Theme.spacingLg
            anchors.right: markButton.left
            anchors.rightMargin: Theme.spacingSm
            anchors.verticalCenter: parent.verticalCenter
            text: appRow.name
            color: rowMouse.containsMouse ? Theme.menuHoverText : Theme.menuText
            elide: Text.ElideRight
        }

        Rectangle {
            id: markButton

            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingSm
            anchors.verticalCenter: parent.verticalCenter
            width: appRow.mark.length > 0 ? root.rowHeight - Theme.spacingSm * 2 : 0
            height: width
            radius: Theme.controlRadius
            color: markMouse.containsMouse ? Theme.controlHoverFill : Theme.transparent

            IconText {
                anchors.centerIn: parent
                text: appRow.mark
                color: appRow.markActive ? Theme.accent : Theme.menuMutedText
                font.pixelSize: Theme.scaledFontSize(14, 8)
            }

            MouseArea {
                id: markMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: appRow.markClicked()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.close()
    }

    // Clicks on the card, padding included, never reach the dismiss area.
    MouseArea {
        x: card.x
        y: card.y
        width: card.width
        height: card.height
        acceptedButtons: Qt.LeftButton | Qt.RightButton
    }

    ShellSurface {
        id: card

        // Next to the click, away from the dock edge, kept on screen.
        x: Math.round(Math.max(root.gap, Math.min(root.width - width - root.gap,
            root.edge === "left" ? root.clickX + root.gap
            : root.edge === "right" ? root.clickX - root.gap - width
            : root.clickX - width / 2)))
        y: Math.round(Math.max(root.gap, Math.min(root.height - height - root.gap,
            root.edge === "top" ? root.clickY + root.gap
            : root.edge === "bottom" ? root.clickY - root.gap - height
            : root.clickY - height / 2)))
        width: root.cardWidth
        height: implicitHeight
        implicitHeight: column.implicitHeight + margin * 2
        margin: Theme.spacingLg

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.spacingSm

            // Clicked app.
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.hasTarget
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.spacingMd
                    Layout.bottomMargin: Theme.spacingSm
                    spacing: Theme.spacingLg

                    IconImage {
                        implicitSize: Theme.scaledSize(28)
                        source: root.hasTarget ? root.targetItem.icon : ""
                        asynchronous: true
                    }

                    UiText {
                        Layout.fillWidth: true
                        text: root.hasTarget ? root.targetItem.name : ""
                        color: Theme.textStrong
                        font.weight: Theme.styleFontWeightStrong
                        elide: Text.ElideRight
                    }
                }

                // Trash actions.
                MenuRow {
                    Layout.fillWidth: true
                    visible: root.targetIsTrash
                    implicitHeight: root.rowHeight
                    label: "Open"
                    onActivated: {
                        root.openTrashRequested();
                        root.close();
                    }
                }

                MenuRow {
                    Layout.fillWidth: true
                    visible: root.targetIsTrash && !root.confirmEmpty
                    enabled: root.trashFull
                    implicitHeight: root.rowHeight
                    label: "Empty Trash"
                    detail: root.trashFull ? "" : "Empty"
                    onActivated: root.confirmEmpty = true
                }

                // Confirmation: the items are deleted for good.
                UiText {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.controlPaddingX
                    Layout.rightMargin: Theme.controlPaddingX
                    visible: root.targetIsTrash && root.confirmEmpty
                    text: "Permanently delete " + root.trashCount
                        + (root.trashCount === 1 ? " item" : " items") + " in the Trash?"
                    color: Theme.textStrong
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacingSm
                    visible: root.targetIsTrash && root.confirmEmpty
                    spacing: Theme.spacingSm

                    Repeater {
                        model: [
                            { "id": "cancel", "label": "Cancel" },
                            { "id": "empty", "label": "Empty Trash" }
                        ]

                        delegate: Rectangle {
                            id: confirmButton

                            required property var modelData
                            readonly property bool destructive: modelData.id === "empty"

                            Layout.fillWidth: true
                            implicitHeight: Theme.scaledSize(28)
                            radius: Theme.controlRadius
                            color: confirmMouse.containsMouse
                                ? (destructive ? Theme.dangerSurface : Theme.controlHoverFill)
                                : Theme.controlNormalFill
                            border.color: destructive ? Theme.danger : Theme.controlNormalBorder
                            border.width: Theme.controlBorderWidth

                            UiText {
                                anchors.centerIn: parent
                                text: confirmButton.modelData.label
                                color: confirmButton.destructive ? Theme.danger : Theme.text
                            }

                            MouseArea {
                                id: confirmMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (confirmButton.destructive) {
                                        root.emptyTrashRequested();
                                        root.close();
                                    } else {
                                        root.confirmEmpty = false;
                                    }
                                }
                            }
                        }
                    }
                }

                MenuRow {
                    Layout.fillWidth: true
                    visible: root.hasTarget && root.targetItem.windowId !== ""
                    implicitHeight: root.rowHeight
                    label: "Show"
                    onActivated: {
                        root.desktopState.focusWindow(root.targetItem.windowId);
                        root.close();
                    }
                }

                MenuRow {
                    Layout.fillWidth: true
                    visible: root.hasTarget && root.targetItem.id !== ""
                    implicitHeight: root.rowHeight
                    label: root.hasTarget && root.targetItem.windowId !== "" ? "New Window" : "Open"
                    onActivated: {
                        root.launchRequested(root.targetItem.id);
                        root.close();
                    }
                }

                MenuRow {
                    Layout.fillWidth: true
                    visible: root.hasTarget && root.targetItem.id !== ""
                    implicitHeight: root.rowHeight
                    label: root.hasTarget && root.dockSettings.isPinned(root.targetItem.id)
                        ? "Remove from Dock" : "Keep in Dock"
                    onActivated: {
                        root.dockSettings.togglePinned(root.targetItem.id);
                        root.close();
                    }
                }

                MenuRow {
                    Layout.fillWidth: true
                    visible: root.hasTarget && root.targetItem.windowId !== "" && !root.confirmQuit
                    implicitHeight: root.rowHeight
                    label: "Quit"
                    onActivated: {
                        if (root.otherDesktops.length > 0)
                            root.confirmQuit = true;
                        else
                            root.quitTarget();
                    }
                }

                // Confirmation when the app has windows on other desktops.
                UiText {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.controlPaddingX
                    Layout.rightMargin: Theme.controlPaddingX
                    visible: root.confirmQuit
                    text: "Quit " + (root.hasTarget ? root.targetItem.name : "") + "? It has windows on "
                        + (root.otherDesktops.length === 1 ? "desktop " : "desktops ")
                        + root.otherDesktops.join(", ") + "."
                    color: Theme.textStrong
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacingSm
                    visible: root.confirmQuit
                    spacing: Theme.spacingSm

                    Repeater {
                        model: [
                            { "id": "cancel", "label": "Cancel" },
                            { "id": "quit", "label": "Quit" }
                        ]

                        delegate: Rectangle {
                            id: quitButton

                            required property var modelData
                            readonly property bool destructive: modelData.id === "quit"

                            Layout.fillWidth: true
                            implicitHeight: Theme.scaledSize(28)
                            radius: Theme.controlRadius
                            color: quitMouse.containsMouse
                                ? (destructive ? Theme.dangerSurface : Theme.controlHoverFill)
                                : Theme.controlNormalFill
                            border.color: destructive ? Theme.danger : Theme.controlNormalBorder
                            border.width: Theme.controlBorderWidth

                            UiText {
                                anchors.centerIn: parent
                                text: quitButton.modelData.label
                                color: quitButton.destructive ? Theme.danger : Theme.text
                            }

                            MouseArea {
                                id: quitMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (quitButton.destructive)
                                        root.quitTarget();
                                    else
                                        root.confirmQuit = false;
                                }
                            }
                        }
                    }
                }

                PanelSeparator {
                    Layout.topMargin: Theme.spacingSm
                    Layout.bottomMargin: Theme.spacingSm
                }
            }

            // Open apps.
            SectionLabel {
                label: "Open apps"
                Layout.leftMargin: Theme.spacingMd
            }

            UiText {
                visible: root.runningItems.length === 0
                Layout.leftMargin: Theme.spacingMd
                Layout.preferredHeight: root.rowHeight
                text: "No open apps"
                color: Theme.menuMutedText
            }

            Repeater {
                model: root.runningItems

                delegate: AppRow {
                    required property var modelData

                    iconSource: modelData.icon
                    name: modelData.name
                    mark: modelData.id !== "" ? "󰐃" : ""
                    markActive: root.dockSettings.isPinned(modelData.id)
                    onClicked: {
                        root.desktopState.focusWindow(modelData.windowId);
                        root.close();
                    }
                    onMarkClicked: root.dockSettings.togglePinned(modelData.id)
                }
            }

            PanelSeparator {
                Layout.topMargin: Theme.spacingSm
                Layout.bottomMargin: Theme.spacingSm
            }

            // Installed apps to pin.
            SectionLabel {
                label: "Apps in Dock"
                Layout.leftMargin: Theme.spacingMd
            }

            ListView {
                id: appList

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, root.rowHeight * 9)
                clip: true
                spacing: 1
                boundsBehavior: Flickable.StopAtBounds
                model: root.allApps

                delegate: AppRow {
                    required property var modelData

                    width: ListView.view.width
                    iconSource: Icons.launcherIcon(modelData.icon)
                    name: modelData.name
                    readonly property bool pinned: root.pinnedIdFor(modelData).length > 0

                    mark: pinned ? "󰄬" : "󰐕"
                    markActive: pinned
                    onClicked: root.togglePinnedEntry(modelData)
                    onMarkClicked: root.togglePinnedEntry(modelData)
                }
            }

            PanelSeparator {
                Layout.topMargin: Theme.spacingSm
                Layout.bottomMargin: Theme.spacingSm
            }

            // Dock edge.
            SectionLabel {
                label: "Position"
                Layout.leftMargin: Theme.spacingMd
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Repeater {
                    model: [
                        { "id": "left", "label": "Left" },
                        { "id": "bottom", "label": "Bottom" },
                        { "id": "top", "label": "Top" },
                        { "id": "right", "label": "Right" }
                    ]

                    delegate: Rectangle {
                        id: edgeButton

                        required property var modelData
                        readonly property bool selected: root.dockSettings.position === modelData.id

                        Layout.fillWidth: true
                        implicitHeight: Theme.scaledSize(28)
                        radius: Theme.controlRadius
                        color: selected ? Theme.controlSelectedFill
                            : edgeMouse.containsMouse ? Theme.controlHoverFill : Theme.controlNormalFill
                        border.color: selected ? Theme.controlSelectedBorder : Theme.controlNormalBorder
                        border.width: Theme.controlBorderWidth

                        UiText {
                            anchors.centerIn: parent
                            text: edgeButton.modelData.label
                            color: edgeButton.selected ? Theme.controlSelectedText : Theme.text
                        }

                        MouseArea {
                            id: edgeMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.close();
                                root.dockSettings.setPosition(edgeButton.modelData.id);
                            }
                        }
                    }
                }
            }

            MenuRow {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacingSm
                implicitHeight: root.rowHeight
                label: "Show Trash"
                detail: root.dockSettings.showTrash ? "On" : "Off"
                active: root.dockSettings.showTrash
                onActivated: root.dockSettings.setShowTrash(!root.dockSettings.showTrash)
            }

            MenuRow {
                Layout.fillWidth: true
                implicitHeight: root.rowHeight
                label: "Auto-hide"
                detail: root.dockSettings.autoHide ? "On" : "Off"
                active: root.dockSettings.autoHide
                onActivated: {
                    root.close();
                    root.dockSettings.setAutoHide(!root.dockSettings.autoHide);
                }
            }

            MenuRow {
                Layout.fillWidth: true
                implicitHeight: root.rowHeight
                label: "Hide Dock"
                detail: "Control Center"
                onActivated: {
                    root.close();
                    root.dockSettings.setEnabled(false);
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

pragma ComponentBehavior: Bound

// macOS style dock for styles with dock = true. Favorites come from the
// style's dock_apps; running windows come from DwmState, so the dock is fully
// event-driven. The window reserves only its rest height (dwm reads the
// strut); the extra height above it is room for magnified icons, and the
// input mask keeps clicks outside the pill going to the windows below.
// qmllint disable uncreatable-type
PanelWindow {
    id: root

    required property var desktopState

    readonly property int iconSize: Theme.scaledSize(Theme.styleDockIconSize)
    readonly property int padding: Theme.scaledSize(7)
    readonly property int bottomMargin: Theme.scaledSize(8)
    readonly property int spacing: Theme.scaledSize(6)
    readonly property int separatorWidth: Theme.scaledSize(9)
    readonly property int dotRoom: Theme.scaledSize(7)
    readonly property real maxScale: Math.max(1, Theme.styleDockMagnify / 100)
    readonly property int magnifyRoom: Math.ceil(iconSize * (maxScale - 1))
    readonly property int pillHeight: iconSize + dotRoom + padding * 2
    readonly property int reservedHeight: pillHeight + bottomMargin
    readonly property var items: root.buildItems(Theme.styleDockApps, root.desktopState.runningApps,
        DesktopEntries.applications)
    // Rest-size geometry: magnification reads the pointer against these
    // fixed centres, so growing icons never feed back into their own scale.
    readonly property var restCenters: root.computeCenters(root.items)
    readonly property int restWidth: root.items.length === 0 ? 0
        : root.restCenters[root.restCenters.length - 1] + root.iconSize / 2 + root.padding

    function sameApp(entry, appClass) {
        const cls = String(appClass).toLowerCase();
        const id = String(entry.id).toLowerCase();
        return cls.length > 0 && (cls === String(entry.startupClass).toLowerCase()
            || cls === id || cls === id.split(".").pop());
    }

    function buildItems(favorites, running, applications) {
        const out = [];
        const used = {};
        // Favorites without an installed desktop entry are skipped.
        const entries = favorites.map(id => DesktopEntries.byId(id) || null)
            .filter(entry => entry !== null);
        for (const entry of entries) {
            let windowId = "";
            for (const app of running) {
                if (!used[app.windowId] && root.sameApp(entry, app.appClass)) {
                    windowId = windowId.length > 0 ? windowId : app.windowId;
                    used[app.windowId] = true;
                }
            }
            out.push({ "id": entry.id, "icon": Icons.launcherIcon(entry.icon), "windowId": windowId });
        }
        const extra = [];
        const seen = {};
        for (const app of running) {
            const cls = String(app.appClass);
            if (used[app.windowId] || seen[cls])
                continue;
            seen[cls] = true;
            const entry = DesktopEntries.heuristicLookup(cls);
            extra.push({
                "id": entry ? entry.id : "",
                "icon": Icons.launcherIcon(entry ? entry.icon : cls),
                "windowId": app.windowId
            });
        }
        if (out.length > 0 && extra.length > 0)
            out.push({ "separator": true, "windowId": "" });
        return out.concat(extra);
    }

    function computeCenters(list) {
        const centers = [];
        let x = root.padding;
        for (const item of list) {
            if (item.separator === true) {
                centers.push(x + root.separatorWidth / 2);
                x += root.separatorWidth + root.spacing;
            } else {
                centers.push(x + root.iconSize / 2);
                x += root.iconSize + root.spacing;
            }
        }
        return centers;
    }

    function scaleFor(index) {
        if (!hover.hovered || root.maxScale <= 1 || Theme.reducedMotion)
            return 1;
        const restLeft = (root.width - root.restWidth) / 2;
        const distance = Math.abs(hover.point.position.x - restLeft - root.restCenters[index])
            / (root.iconSize + root.spacing);
        if (distance >= 2.5)
            return 1;
        return 1 + (root.maxScale - 1) * Math.cos(distance / 2.5 * Math.PI / 2);
    }

    function activate(item) {
        if (item.windowId !== "") {
            root.desktopState.focusWindow(item.windowId);
        } else if (item.id !== "") {
            launchProcess.command = Commands.launcherHelperCommand("launch-id", [item.id]);
            launchProcess.running = true;
        }
    }

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    visible: root.items.length > 0
    color: Theme.transparent
    implicitHeight: root.reservedHeight + root.magnifyRoom
    exclusiveZone: root.reservedHeight
    aboveWindows: root.desktopState.fullscreenMonitorIndexes.indexOf(
        root.desktopState.screenIndex(root.screen)) === -1
    mask: Region { item: pill }

    anchors {
        bottom: true
        left: true
        right: true
    }

    Item {
        anchors.fill: parent

        HoverHandler {
            id: hover
        }

        Rectangle {
            id: pill

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.bottomMargin
            width: row.width + root.padding * 2
            height: root.pillHeight
            radius: Theme.scaledSize(Theme.styleDockRadius)
            color: Theme.withAlpha(Theme.bg, Theme.styleDockOpacity)
            border.color: Theme.withAlpha(Theme.textStrong, 15)
            border.width: 1
        }

        Row {
            id: row

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: pill.bottom
            anchors.bottomMargin: root.padding
            height: root.iconSize * root.maxScale + root.dotRoom
            spacing: root.spacing

            Repeater {
                model: root.items

                delegate: DockItem {
                    required property var modelData
                    required property int index

                    dockItem: modelData
                    iconSize: root.iconSize
                    scaleFactor: root.scaleFor(index)
                    onActivated: root.activate(modelData)
                }
            }
        }
    }

    Process {
        id: launchProcess
    }
}

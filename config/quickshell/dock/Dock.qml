import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.core

pragma ComponentBehavior: Bound

// macOS style dock. Pinned apps come from DockSettings (the style's dock_apps
// until the user edits them), running windows from DwmState, so the dock is
// fully event-driven. It can sit on any screen edge, with an optional Trash at
// the far end.
//
// Two surfaces. This panel window draws nothing: its shape is the rounded
// pill, so the compositor blurs exactly behind it. The pill itself (background
// and border) and the icons are drawn together in an override-redirect popup
// on top, which the compositor does not blur, so the pill lengthens in step
// with the magnified icons; it keeps its height and the icons rise above it
// into a band the popup's shape opens while hovered. The
// window reserves only its rest thickness (dwm reads the strut). Right click
// opens the dock menu.
//
// Auto-hide: the dock slides off its edge and reserves nothing (1 px, so dwm
// still sees a dock). The windows keep their size, so nothing jumps while it
// slides; the blur is off while the dock moves or is hidden and comes back
// once it rests. A thin strip on the icon layer along the screen edge brings
// the dock back when the pointer touches it.
// qmllint disable uncreatable-type
PanelWindow {
    id: root

    required property var desktopState
    required property var dockSettings

    readonly property string edge: root.dockSettings.position
    readonly property bool vertical: root.edge === "left" || root.edge === "right"
    readonly property int iconSize: Theme.scaledSize(Theme.styleDockIconSize)
    readonly property int padding: Theme.scaledSize(7)
    readonly property int edgeMargin: Theme.scaledSize(8)
    readonly property int spacing: Theme.scaledSize(6)
    readonly property int separatorSize: Theme.scaledSize(9)
    readonly property int dotRoom: Theme.scaledSize(7)
    readonly property real maxScale: Math.max(1, Theme.styleDockMagnify / 100)
    readonly property int magnifyRoom: Math.ceil(iconSize * (maxScale - 1))
    readonly property int pillThickness: iconSize + dotRoom + padding * 2
    readonly property int reservedSize: pillThickness + edgeMargin
    readonly property int crossSize: Math.ceil(iconSize * maxScale) + dotRoom
    readonly property int maxIconSize: Math.ceil(iconSize * maxScale)
    readonly property bool onTop: root.desktopState.fullscreenMonitorIndexes.indexOf(
        root.desktopState.screenIndex(root.screen)) === -1
    // 0 at rest, 1 while hovered. Only entering and leaving animate; while the
    // pointer moves the icons follow it directly.
    // No magnification while an auto-hidden dock is still sliding in.
    property real magnify: hover.hovered && !dockMenu.visible && root.maxScale > 1
        && !Theme.reducedMotion && root.hiddenAmount === 0 ? 1 : 0
    Behavior on magnify {
        NumberAnimation { duration: Math.round(Theme.animationNormal * 4 / 3); easing.type: Easing.OutCubic }
    }
    readonly property int fullThickness: root.reservedSize + root.magnifyRoom
    readonly property bool autoHide: root.dockSettings.autoHide
    // Shown unless auto-hide is on and neither the dock, its edge strip nor
    // its menu has the pointer. Showing is immediate; hiding waits a moment,
    // so a pointer that grazes the edge or slips off the dock does not make it
    // flicker.
    readonly property bool wantShown: !root.autoHide || hover.hovered || dockMenu.visible
    property bool revealed: true
    onWantShownChanged: {
        if (root.wantShown) {
            hideDelay.stop();
            root.revealed = true;
        } else {
            hideDelay.restart();
        }
    }
    property real hiddenAmount: root.revealed ? 0 : 1
    Behavior on hiddenAmount {
        NumberAnimation { duration: Math.round(Theme.animationNormal * 4 / 3); easing.type: Easing.OutCubic }
    }
    // How far the pill moves out past the screen edge when hidden.
    readonly property real slide: root.hiddenAmount * root.fullThickness
    // The frame the icon layer and the pill geometry live in: the full dock
    // area, whatever size the blur window has right now.
    readonly property int frameWidth: root.vertical ? root.fullThickness : root.width
    readonly property int frameHeight: root.vertical ? root.height : root.fullThickness
    // The blur window's offset inside that frame (it shrinks toward the edge).
    readonly property int blurOffsetX: root.edge === "right" ? root.frameWidth - root.width : 0
    readonly property int blurOffsetY: root.edge === "bottom" ? root.frameHeight - root.height : 0
    // Blur only behind a dock at rest. X11 re-applies this window's shape only
    // when the window is resized, so it is 1 px thinner whenever the blur is
    // off: each switch is a resize, and the shape follows.
    readonly property bool blurVisible: root.hiddenAmount === 0
    // The blur covers the pill at its rest length: the shape is not re-applied
    // while the pill lengthens under the pointer, so tying it to the live
    // length would leave it long after the pill shrinks back.
    readonly property int blurW: root.vertical ? root.pillThickness : Math.round(root.restLength)
    readonly property int blurH: root.vertical ? Math.round(root.restLength) : root.pillThickness
    readonly property real blurX: !root.blurVisible ? -100000
        : root.vertical ? pill.x - root.blurOffsetX
        : Math.round((root.frameWidth - root.blurW) / 2) - root.blurOffsetX
    readonly property real blurY: !root.blurVisible ? -100000
        : root.vertical ? Math.round((root.frameHeight - root.blurH) / 2) - root.blurOffsetY
        : pill.y - root.blurOffsetY
    readonly property int maskRadius: Math.min(Theme.scaledSize(Theme.styleDockRadius), Math.floor(pillThickness / 2))
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string trashDir: (Quickshell.env("XDG_DATA_HOME") || root.homeDir + "/.local/share") + "/Trash/files"
    readonly property bool trashFull: trashFiles.count > 0
    // applications.values changes when the desktop entries finish loading
    // (and on every rescan); the model object itself never changes, so
    // depending on it alone would freeze an empty dock at startup.
    readonly property var items: root.buildItems(root.dockSettings.apps, root.desktopState.runningApps,
        DesktopEntries.applications.values, root.dockSettings.showTrash, root.trashFull)
    // Rest-size geometry: magnification reads the pointer against these
    // fixed centres, so growing icons never feed back into their own scale.
    readonly property var restCenters: root.computeCenters(root.items)
    readonly property int restLength: root.items.length === 0 ? 0
        : root.restCenters[root.restCenters.length - 1] + root.iconSize / 2 + root.padding

    function sameApp(entry, appClass) {
        const cls = String(appClass).toLowerCase();
        const id = String(entry.id).toLowerCase();
        return cls.length > 0 && (cls === String(entry.startupClass).toLowerCase()
            || cls === id || cls === id.split(".").pop());
    }

    function prettyClass(cls) {
        const name = String(cls).split(/[.-]/).pop();
        return name.charAt(0).toUpperCase() + name.substring(1);
    }

    function buildItems(pinned, running, applications, showTrash, trashFull) {
        const out = [];
        const used = {};
        // Pinned apps without an installed desktop entry are skipped.
        const entries = pinned.map(id => DesktopEntries.byId(id) || null)
            .filter(entry => entry !== null);
        for (const entry of entries) {
            let windowId = "";
            let appClass = "";
            for (const app of running) {
                if (!used[app.windowId] && root.sameApp(entry, app.appClass)) {
                    if (windowId.length === 0) {
                        windowId = app.windowId;
                        appClass = app.appClass;
                    }
                    used[app.windowId] = true;
                }
            }
            out.push({ "id": entry.id, "name": entry.name, "icon": Icons.launcherIcon(entry.icon),
                "windowId": windowId, "appClass": appClass, "pinned": true });
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
                "name": entry ? entry.name : root.prettyClass(cls),
                "icon": Icons.launcherIcon(entry ? entry.icon : cls),
                "windowId": app.windowId,
                "appClass": cls,
                "pinned": false
            });
        }
        if (out.length > 0 && extra.length > 0)
            out.push({ "separator": true, "windowId": "" });
        const list = out.concat(extra);
        // The Trash always closes the dock, after a separator.
        if (showTrash) {
            if (list.length > 0)
                list.push({ "separator": true, "windowId": "" });
            list.push({ "trash": true, "id": "", "name": "Trash", "windowId": "",
                "icon": Icons.launcherIcon(trashFull ? "user-trash-full" : "user-trash") });
        }
        return list;
    }

    function computeCenters(list) {
        const centers = [];
        let pos = root.padding;
        for (const item of list) {
            if (item.separator === true) {
                centers.push(pos + root.separatorSize / 2);
                pos += root.separatorSize + root.spacing;
            } else {
                centers.push(pos + root.iconSize / 2);
                pos += root.iconSize + root.spacing;
            }
        }
        return centers;
    }

    function scaleFor(index) {
        if (root.magnify <= 0)
            return 1;
        const axisLength = root.vertical ? root.height : root.width;
        const pointer = root.vertical ? hover.point.position.y : hover.point.position.x;
        const restStart = (axisLength - root.restLength) / 2;
        const distance = Math.abs(pointer - restStart - root.restCenters[index])
            / (root.iconSize + root.spacing);
        if (distance >= 2.5)
            return 1;
        return 1 + (root.maxScale - 1) * root.magnify * Math.cos(distance / 2.5 * Math.PI / 2);
    }

    function run(command) {
        actionProcess.command = command;
        actionProcess.running = true;
    }

    function launch(id) {
        if (id === "") return;
        root.run(Commands.launcherHelperCommand("launch-id", [id]));
    }

    function openTrash() {
        root.run(["gio", "open", "trash:///"]);
    }

    function emptyTrash() {
        root.run(["gio", "trash", "--empty"]);
    }

    function activate(item) {
        if (item.trash === true)
            root.openTrash();
        else if (item.windowId !== "")
            root.desktopState.focusWindow(item.windowId);
        else
            root.launch(item.id);
    }

    function openMenu(item, x, y) {
        dockMenu.targetItem = item;
        dockMenu.anchorX = x;
        dockMenu.anchorY = y;
        dockMenu.visible = true;
    }

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    visible: root.items.length > 0
    color: Theme.transparent
    implicitHeight: root.vertical ? 0 : root.fullThickness - (root.blurVisible ? 0 : 1)
    implicitWidth: root.vertical ? root.fullThickness - (root.blurVisible ? 0 : 1) : 0
    exclusiveZone: root.autoHide ? 1 : root.reservedSize
    aboveWindows: root.onTop
    // On X11 the mask is the window's bounding shape: it clips input, drawing
    // and the Picom blur behind the dock. It is always the rounded pill.
    mask: Region {
        x: root.blurX + root.maskRadius
        y: root.blurY
        width: root.blurW - root.maskRadius * 2
        height: root.blurH

        Region {
            x: root.blurX
            y: root.blurY + root.maskRadius
            width: root.blurW
            height: root.blurH - root.maskRadius * 2
        }
        Region {
            shape: RegionShape.Ellipse
            x: root.blurX
            y: root.blurY
            width: root.maskRadius * 2
            height: root.maskRadius * 2
        }
        Region {
            shape: RegionShape.Ellipse
            x: root.blurX + root.blurW - root.maskRadius * 2
            y: root.blurY
            width: root.maskRadius * 2
            height: root.maskRadius * 2
        }
        Region {
            shape: RegionShape.Ellipse
            x: root.blurX
            y: root.blurY + root.blurH - root.maskRadius * 2
            width: root.maskRadius * 2
            height: root.maskRadius * 2
        }
        Region {
            shape: RegionShape.Ellipse
            x: root.blurX + root.blurW - root.maskRadius * 2
            y: root.blurY + root.blurH - root.maskRadius * 2
            width: root.maskRadius * 2
            height: root.maskRadius * 2
        }
    }

    anchors {
        bottom: root.edge !== "top"
        top: root.edge !== "bottom"
        left: root.edge !== "right"
        right: root.edge !== "left"
    }
    // A top dock sits below the bar.
    margins.top: root.edge === "top" ? Theme.panelWindowHeight : 0 // qmllint disable unqualified unresolved-type

    // Pill geometry in frame coordinates, shared by the blur shape here and the
    // drawn pill above. The blur shape keeps the rest length while hovered:
    // this window draws nothing, so its shape is only re-applied on a resize.
    Item {
        id: pill

        x: root.edge === "left" ? root.edgeMargin - root.slide
            : root.edge === "right" ? root.frameWidth - root.edgeMargin - width + root.slide
            : Math.round((root.frameWidth - width) / 2)
        y: root.edge === "top" ? root.edgeMargin - root.slide
            : root.edge === "bottom" ? root.frameHeight - root.edgeMargin - height + root.slide
            : Math.round((root.frameHeight - height) / 2)
        // Lengthens with the icons, never thickens.
        width: root.vertical ? root.pillThickness : Math.round(grid.width) + root.padding * 2
        height: root.vertical ? Math.round(grid.height) + root.padding * 2 : root.pillThickness
    }

    // The icons, above the pill at the same position and size as the dock
    // window. Hover, clicks and magnification all happen here.
    PopupWindow {
        id: iconLayer

        // Anchored at the corner on the screen edge, growing inward, so the
        // layer keeps the full dock frame while the blur window shrinks.
        readonly property bool fromBottom: root.edge === "bottom"
        readonly property bool fromRight: root.edge === "right"

        anchor.window: root
        anchor.rect.x: fromRight ? root.width - 1 : 0
        anchor.rect.y: fromBottom ? root.height - 1 : 0
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: (fromBottom ? Edges.Bottom : Edges.Top) | (fromRight ? Edges.Right : Edges.Left) // qmllint disable missing-type
        anchor.gravity: (fromBottom ? Edges.Top : Edges.Bottom) | (fromRight ? Edges.Left : Edges.Right) // qmllint disable missing-type
        anchor.adjustment: PopupAdjustment.None // qmllint disable missing-type

        visible: root.visible && root.onTop
        color: Theme.transparent
        implicitWidth: root.frameWidth
        implicitHeight: root.frameHeight
        // The pill, the band magnified icons rise into while hovered, and with
        // auto-hide the strip along the screen edge.
        mask: Region {
            x: pill.x
            y: pill.y
            width: pill.width
            height: pill.height

            Region { item: magnifyBand }
            Region { item: edgeStrip }
            Region { item: edgeGap }
            Region { item: slideArea }
        }

        Item {
            id: content

            anchors.fill: parent

            HoverHandler {
                id: hover
            }

            Rectangle {
                x: pill.x
                y: pill.y
                width: pill.width
                height: pill.height
                radius: Theme.scaledSize(Theme.styleDockRadius)
                color: Theme.withAlpha(Theme.bg, Theme.styleDockOpacity)
                border.color: Theme.withAlpha(Theme.textStrong, 15)
                border.width: 1
            }

            MouseArea {
                x: pill.x
                y: pill.y
                width: pill.width
                height: pill.height
                acceptedButtons: Qt.RightButton
                onClicked: mouse => {
                    const p = mapToItem(null, mouse.x, mouse.y);
                    root.openMenu(null, p.x, p.y);
                }
            }

            // While hovered the shape covers the pill at its longest plus the
            // band magnified icons rise into. It is fixed for the whole hover,
            // so the X11 shape never trails the animation and clips the icons
            // or the pill's ends.
            Item {
                id: magnifyBand

                readonly property bool open: root.magnify > 0
                readonly property int depth: open && root.magnifyRoom > 0 ? root.magnifyRoom : 0
                readonly property int thickness: open ? depth + root.pillThickness : 0
                readonly property int length: root.restLength + root.maxIconSize * 4
                readonly property int axisLength: root.vertical ? content.height : content.width
                readonly property int start: Math.round((axisLength - length) / 2)

                x: root.edge === "left" ? pill.x
                    : root.edge === "right" ? pill.x + pill.width - thickness
                    : start
                y: root.edge === "top" ? pill.y
                    : root.edge === "bottom" ? pill.y + pill.height - thickness
                    : start
                width: root.vertical ? thickness : (open ? length : 0)
                height: root.vertical ? (open ? length : 0) : thickness
            }

            // Auto-hide trigger: a 2 px strip along the whole screen edge,
            // always the same, so revealing the dock never moves it away from
            // the pointer.
            Item {
                id: edgeStrip

                readonly property int thickness: root.autoHide ? 2 : 0

                x: root.edge === "right" ? root.frameWidth - thickness : 0
                y: root.edge === "bottom" ? root.frameHeight - thickness : 0
                width: root.vertical ? thickness : root.frameWidth
                height: root.vertical ? root.frameHeight : thickness
            }

            // Auto-hide: while the dock is shown or sliding, the shape is one
            // fixed area covering everything it can occupy, so the X11 shape
            // never has to follow the slide and never clips the moving icons.
            Item {
                id: slideArea

                readonly property bool active: root.autoHide && root.hiddenAmount < 1
                readonly property int length: active ? magnifyBand.length : 0
                readonly property int thickness: active ? root.fullThickness : 0

                x: root.vertical ? (root.edge === "right" ? root.frameWidth - thickness : 0) : magnifyBand.start
                y: root.vertical ? magnifyBand.start : (root.edge === "bottom" ? root.frameHeight - thickness : 0)
                width: root.vertical ? thickness : length
                height: root.vertical ? length : thickness
            }

            // While shown, the gap between the edge and the pill also counts,
            // so the pointer never drops out of the dock on its way to it.
            Item {
                id: edgeGap

                readonly property int thickness: root.autoHide && root.revealed ? root.edgeMargin + 1 : 0

                x: root.edge === "left" ? 0
                    : root.edge === "right" ? root.frameWidth - thickness
                    : pill.x
                y: root.edge === "top" ? 0
                    : root.edge === "bottom" ? root.frameHeight - thickness
                    : pill.y
                width: root.vertical ? thickness : pill.width
                height: root.vertical ? pill.height : thickness
            }

            Grid {
                id: grid

                columns: root.vertical ? 1 : Math.max(1, root.items.length)
                spacing: root.spacing
                x: root.edge === "left" ? pill.x + root.padding
                    : root.edge === "right" ? pill.x + pill.width - root.padding - width
                    : Math.round((content.width - width) / 2)
                y: root.edge === "top" ? pill.y + root.padding
                    : root.edge === "bottom" ? pill.y + pill.height - root.padding - height
                    : Math.round((content.height - height) / 2)

                Repeater {
                    model: root.items

                    delegate: DockItem {
                        required property var modelData
                        required property int index

                        dockItem: modelData
                        edge: root.edge
                        iconSize: root.iconSize
                        crossSize: root.crossSize
                        maxIconSize: root.maxIconSize
                        scaleFactor: root.scaleFor(index)
                        onActivated: root.activate(modelData)
                        onMenuRequested: (x, y) => root.openMenu(modelData, x, y)
                    }
                }
            }
        }
    }

    DockMenu {
        id: dockMenu

        dockWindow: root
        desktopState: root.desktopState
        dockSettings: root.dockSettings
        edge: root.edge
        trashFull: root.trashFull
        trashCount: trashFiles.count
        runningItems: root.items.filter(item => item.separator !== true && item.windowId !== "")
        onLaunchRequested: id => root.launch(id)
        onOpenTrashRequested: root.openTrash()
        onEmptyTrashRequested: root.emptyTrash()
    }

    // Watches the Trash so its icon shows empty or full, without polling.
    FolderListModel {
        id: trashFiles

        folder: "file://" + root.trashDir
        showDirs: true
        showHidden: true
        showDotAndDotDot: false
    }

    Process {
        id: actionProcess
    }

    // The delay before an auto-hidden dock slides away.
    SequentialAnimation {
        id: hideDelay

        PauseAnimation { duration: 350 }
        ScriptAction { script: root.revealed = false }
    }
}

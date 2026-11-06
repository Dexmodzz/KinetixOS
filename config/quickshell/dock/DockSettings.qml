import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

pragma ComponentBehavior: Bound

// User dock preferences, stored in ~/.config/kinetixos/dock.json:
// visibility ("style" follows the theme, "on" or "off"), screen edge, the
// Trash at the end of the dock, auto-hide and the pinned apps. Pinned apps start from the
// style's dock_apps and become a user list on the first pin or unpin. The file
// is written only on a change.
Scope {
    id: root

    readonly property var edges: ["bottom", "top", "left", "right"]
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configuredConfigHome: Quickshell.env("XDG_CONFIG_HOME") || ""
    readonly property string configHome: root.configuredConfigHome.startsWith("/")
        ? root.configuredConfigHome : root.homeDir + "/.config"
    readonly property string configPath: root.configHome + "/kinetixos/dock.json"

    property string visibilityMode: "style"
    property string storedPosition: "bottom"
    property bool customApps: false
    property var storedApps: []
    property bool showTrash: true
    property bool autoHide: false

    readonly property bool enabled: root.visibilityMode === "on"
        || (root.visibilityMode !== "off" && Theme.styleDock)
    readonly property string position: root.edges.indexOf(root.storedPosition) >= 0
        ? root.storedPosition : "bottom"
    readonly property var apps: root.customApps ? root.storedApps : Theme.styleDockApps

    function load(text) {
        let values = {};
        try {
            values = JSON.parse(text);
        } catch (error) {
            return;
        }
        if (typeof values !== "object" || values === null) return;
        root.visibilityMode = ["style", "on", "off"].indexOf(values.visibility) >= 0
            ? values.visibility : "style";
        root.storedPosition = typeof values.position === "string" ? values.position : "bottom";
        root.customApps = values.customApps === true;
        root.showTrash = values.showTrash !== false;
        root.autoHide = values.autoHide === true;
        root.storedApps = Array.isArray(values.apps)
            ? values.apps.filter(app => typeof app === "string" && app.length > 0) : [];
    }

    function save() {
        file.setText(JSON.stringify({
            "visibility": root.visibilityMode,
            "position": root.position,
            "customApps": root.customApps,
            "showTrash": root.showTrash,
            "autoHide": root.autoHide,
            "apps": root.storedApps
        }, null, 2) + "\n");
    }

    function setEnabled(value) {
        root.visibilityMode = value ? "on" : "off";
        root.save();
    }

    function toggleEnabled() {
        root.setEnabled(!root.enabled);
    }

    function setPosition(value) {
        if (root.edges.indexOf(value) < 0) return;
        root.storedPosition = value;
        root.save();
    }

    function setAutoHide(value) {
        root.autoHide = value;
        root.save();
    }

    function setShowTrash(value) {
        root.showTrash = value;
        root.save();
    }

    function isPinned(id) {
        return id.length > 0 && root.apps.indexOf(id) >= 0;
    }

    function setPinned(id, pinned) {
        if (id.length === 0) return;
        const list = root.apps.filter(app => app !== id);
        if (pinned) list.push(id);
        root.storedApps = list;
        root.customApps = true;
        root.save();
    }

    function togglePinned(id) {
        root.setPinned(id, !root.isPinned(id));
    }

    FileView {
        id: file

        path: root.configPath
        watchChanges: true
        printErrors: false
        onLoaded: root.load(text())
        onFileChanged: reload()
    }
}

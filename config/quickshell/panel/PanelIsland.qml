import QtQuick
import qs.core

// Rounded background for one bar island. Only the soft style draws it; the
// classic panel keeps a single full-width strip.
Rectangle {
    visible: Theme.styleBarIslands
    color: Theme.barBackground
    radius: Theme.barRadius
    border.color: Theme.borderSubtle
    border.width: Theme.pillBorderWidth
}

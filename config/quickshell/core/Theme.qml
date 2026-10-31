pragma Singleton

import Quickshell

Singleton {
    id: root

    property bool dark: true
    property bool highContrast: false
    property bool reducedMotion: false

    readonly property string transparent: "#00000000"
    property string bg: "#2E3440"
    property string barBackground: "#434C5E"
    property string surface: "#434C5E"
    property string surfaceHover: "#4C566A"
    property string surfaceActive: "#434C5E"
    property string border: "#3B4252"
    property string borderStrong: "#81A1C1"
    property string text: "#D8DEE9"
    property string textStrong: "#ECEFF4"
    property string paletteTextMuted: "#D8DEE9"
    readonly property string textMuted: highContrast ? text : paletteTextMuted
    property string placeholder: "#4C566A"
    property string accent: "#81A1C1"
    property string accentSecondary: "#81A1C1"
    property string accentText: "#2E3440"
    property string success: "#A3BE8C"
    property string warning: "#EBCB8B"
    property string danger: "#BF616A"
    property string dangerSurface: "#3B4252"
    // Optional roles. Classic themes derive them from the palette above.
    property string surfaceWindow: "#434C5E"
    property string surfaceInput: "#434C5E"
    property string chip: "#434C5E"
    property string textSecondary: "#D8DEE9"
    property string textFaint: "#4C566A"
    readonly property string shadow: transparent

    // Style profile. Defaults are the classic KinetixOS geometry; a theme's
    // style profile from the appearance provider replaces them via applyStyle().
    property string styleName: "classic"
    // Set by the shell from the dwm state stream. Rounded popup corners and
    // transparent bar gaps need a compositor; without one they render black.
    property bool compositorActive: false
    property bool styleBarIslands: false
    property bool styleLauncherFooter: false
    property int styleBarRadius: 0
    property int stylePopupRadius: 0
    property int styleCardRadius: 8
    property int styleControlRadius: 6
    property int styleLogoRadius: 6
    property int stylePillRadius: 6
    property int styleBarHeight: 30
    property int styleBarMarginTop: 0
    property int styleBarMarginSide: 0
    property int stylePopupPadding: 18
    property int styleTitleSize: 24
    property int styleAccentSoftAlpha: 0
    property int styleBorderSubtleAlpha: 0
    property string styleFontFamily: ""
    property int styleFontWeight: 400
    property int styleFontWeightStrong: 700
    readonly property bool softStyle: styleName !== "classic"

    // "#RRGGBB" plus a 0-100 percentage -> "#AARRGGBB".
    function withAlpha(color, percent) {
        const value = String(color);
        if (!/^#[0-9A-Fa-f]{6}$/.test(value)) return value;
        const alpha = Math.round(Math.max(0, Math.min(100, percent)) * 2.55);
        return "#" + (alpha < 16 ? "0" : "") + alpha.toString(16) + value.substring(1);
    }
    readonly property string accentSoft: softStyle ? withAlpha(accent, styleAccentSoftAlpha) : surfaceActive
    readonly property string borderSubtle: softStyle ? withAlpha(accent, styleBorderSubtleAlpha) : border

    // Semantic shell roles. Keep these derived from the existing dwm palette
    // so hot-reloaded themes remain the single source of color state.
    readonly property string popupBackground: bg
    readonly property string popupBorder: highContrast ? textStrong : softStyle ? borderSubtle : borderStrong
    readonly property string popupText: text
    readonly property string menuBackground: bg
    readonly property string menuText: text
    readonly property string menuMutedText: textMuted
    readonly property string menuActionText: accent
    readonly property string menuHoverBackground: surfaceHover
    readonly property string menuHoverText: textStrong
    readonly property string menuSelectedBackground: surfaceActive
    readonly property string menuSelectedText: accentSecondary
    readonly property string controlNormalFill: surface
    readonly property string controlNormalBorder: highContrast ? textStrong : border
    readonly property string controlNormalText: text
    readonly property string controlHoverFill: surfaceHover
    readonly property string controlHoverBorder: highContrast ? textStrong : borderStrong
    readonly property string controlHoverText: text
    readonly property string controlFocusFill: surface
    readonly property string controlFocusBorder: highContrast ? textStrong : accent
    readonly property string controlFocusText: text
    readonly property string controlSelectedFill: surfaceActive
    readonly property string controlSelectedBorder: highContrast ? textStrong : accentSecondary
    readonly property string controlSelectedText: accentSecondary
    readonly property string controlDisabledFill: barBackground
    readonly property string controlDisabledBorder: highContrast ? textStrong : border
    readonly property string controlDisabledText: textMuted

    // AppearanceModel is the single owner of theme inventory and validation.
    // Existing shell surfaces continue to consume these semantic properties.
    function applyAppearanceColors(colors, darkMode) {
        root.dark = darkMode;
        root.bg = colors.background;
        root.barBackground = colors["bar-background"];
        root.surface = colors.surface;
        root.surfaceHover = colors["surface-hover"];
        root.surfaceActive = colors["surface-active"];
        root.border = colors.border;
        root.borderStrong = colors["border-strong"];
        root.text = colors.text;
        root.textStrong = colors["text-strong"];
        root.paletteTextMuted = colors["text-muted"];
        root.placeholder = colors.placeholder;
        root.accent = colors.accent;
        root.accentSecondary = colors["accent-secondary"];
        root.accentText = colors["accent-text"];
        root.success = colors.success;
        root.warning = colors.warning;
        root.danger = colors.danger;
        root.dangerSurface = colors["danger-surface"];
        root.surfaceWindow = root.optionalColor(colors, "surface-window", colors.surface);
        root.surfaceInput = root.optionalColor(colors, "surface-input", colors.surface);
        root.chip = root.optionalColor(colors, "chip", colors["surface-active"]);
        root.textSecondary = root.optionalColor(colors, "text-secondary", colors.text);
        root.textFaint = root.optionalColor(colors, "text-faint", colors.placeholder);
    }

    function optionalColor(colors, name, fallback) {
        const value = colors[name];
        return typeof value === "string" && /^#[0-9A-Fa-f]{6}$/.test(value) ? value : fallback;
    }

    function styleInt(values, name, fallback) {
        const value = Number(values[name]);
        return values[name] !== undefined && isFinite(value) ? Math.round(value) : fallback;
    }

    // Apply a provider style profile; an empty map restores the classic look.
    function applyStyle(name, values) {
        const v = values || {};
        root.styleName = name && name.length > 0 ? name : "classic";
        root.styleBarIslands = v.bar_islands === "true";
        root.styleLauncherFooter = v.launcher_footer === "true";
        root.styleBarRadius = root.styleInt(v, "bar_radius", 0);
        root.stylePopupRadius = root.styleInt(v, "popup_radius", 0);
        root.styleCardRadius = root.styleInt(v, "card_radius", 8);
        root.styleControlRadius = root.styleInt(v, "control_radius", 6);
        root.styleLogoRadius = root.styleInt(v, "logo_radius", root.styleControlRadius);
        root.stylePillRadius = root.styleInt(v, "pill_radius", 6);
        root.styleBarHeight = root.styleInt(v, "bar_height", 30);
        root.styleBarMarginTop = root.styleInt(v, "bar_margin_top", 0);
        root.styleBarMarginSide = root.styleInt(v, "bar_margin_side", 0);
        root.stylePopupPadding = root.styleInt(v, "popup_padding", 18);
        root.styleTitleSize = root.styleInt(v, "title_size", 24);
        root.styleAccentSoftAlpha = root.styleInt(v, "accent_soft_alpha", 0);
        root.styleBorderSubtleAlpha = root.styleInt(v, "border_subtle_alpha", 0);
        root.styleFontFamily = typeof v.font_family === "string" ? v.font_family : "";
        root.styleFontWeight = root.styleInt(v, "font_weight", 400);
        root.styleFontWeightStrong = root.styleInt(v, "font_weight_strong", 700);
    }

    readonly property string defaultFontFamily: "MesloLGS Nerd Font Mono"
    property string requestedFontFamily: defaultFontFamily
    // A style font replaces only the default family, never a font the user
    // picked. AppearanceModel resolves it to an installed family first.
    readonly property string fontFamily: styleFontFamily.length > 0
        && requestedFontFamily === defaultFontFamily ? styleFontFamily : requestedFontFamily
    property real requestedFontScale: 1.0
    property bool desktopTypography: false
    // Qt already scales X11 windows using Xft/DPI. Apply only the remainder
    // here, so a 200% desktop never becomes a 400% shell.
    readonly property real nativeScale: Quickshell.screens.length > 0
        ? Math.max(0.1, Quickshell.screens[0].devicePixelRatio) : 1.0
    readonly property real fontScale: requestedFontScale
        / (desktopTypography ? nativeScale : 1.0)
    readonly property string iconFontFamily: "MesloLGS Nerd Font Mono"

    function applyFontPreferences(family, scale) {
        root.requestedFontFamily = family.length > 0 ? family : root.defaultFontFamily;
        root.requestedFontScale = Math.max(0.75, Math.min(2.0, scale));
    }

    function applyAccessibility(highContrastEnabled, reducedMotionEnabled) {
        root.highContrast = highContrastEnabled;
        root.reducedMotion = reducedMotionEnabled;
    }

    function scaledSize(value) {
        return Math.round(value * root.fontScale);
    }

    function scaledFontSize(value, minimum) {
        // Minimums are desktop pixels too; apply them before DPI compensation.
        const desktopSize = Math.max(minimum, Math.round(value * root.requestedFontScale));
        return Math.max(1, Math.round(desktopSize / (root.desktopTypography ? root.nativeScale : 1.0)));
    }

    // Shared spacing and type scales adapted from Omarchy's shell language.
    // Values intentionally map to the pre-existing KinetixOS geometry.
    readonly property int spacingXxs: scaledSize(2)
    readonly property int spacingXs: scaledSize(3)
    readonly property int spacingSm: scaledSize(4)
    readonly property int spacingMd: scaledSize(6)
    readonly property int spacingLg: scaledSize(8)
    readonly property int spacingXl: scaledSize(10)
    readonly property int spacingXxl: scaledSize(12)
    readonly property int spacingXxxl: scaledSize(14)
    readonly property int spacingHuge: scaledSize(18)

    readonly property int fontCaptionSize: scaledFontSize(10, 8)
    readonly property int fontBodySmallSize: scaledFontSize(12, 10)
    readonly property int fontBodySize: scaledFontSize(13, 10)
    readonly property int fontSubtitleSize: scaledFontSize(14, 11)
    readonly property int fontTitleSize: scaledFontSize(18, 14)
    readonly property int largeSurfaceTitleSize: scaledFontSize(styleTitleSize, Math.min(18, styleTitleSize))
    readonly property int panelIconFontSize: scaledFontSize(14, 8)

    readonly property int controlHeight: scaledSize(30)
    readonly property int controlRowHeight: scaledSize(32)
    readonly property int controlPaddingX: scaledSize(9)
    readonly property int controlBorderWidth: highContrast ? 2 : 1
    readonly property int controlFocusBorderWidth: controlBorderWidth
    readonly property int controlRadius: scaledSize(styleControlRadius)
    readonly property int menuHeaderHeight: scaledSize(26)
    readonly property int popupPadding: scaledSize(stylePopupPadding)
    readonly property int popupRadius: compositorActive ? scaledSize(stylePopupRadius) : 0
    readonly property int panelHeroIconSize: scaledSize(32)
    readonly property real panelMetaLetterSpacing: 1.2 * fontScale
    readonly property int panelSliderHeight: scaledSize(32)
    readonly property int panelSliderTrackHeight: scaledSize(6)
    readonly property int panelSliderKnobSize: scaledSize(16)
    readonly property int panelToggleWidth: scaledSize(40)
    readonly property int panelToggleHeight: scaledSize(22)
    readonly property int panelToggleKnobSize: scaledSize(14)
    readonly property int panelToggleInset: scaledSize(3)

    readonly property int panelHeight: scaledSize(styleBarHeight)
    readonly property int panelMargin: scaledSize(styleBarMarginTop)
    readonly property int panelEdgeMargin: scaledSize(styleBarMarginSide)
    // Height of the panel window and of the space dwm reserves for it.
    readonly property int panelWindowHeight: panelHeight + panelMargin
    readonly property int panelGap: spacingSm
    readonly property int popupMargin: popupPadding
    readonly property int popupSpacing: spacingXxl
    readonly property int controlCenterX: scaledSize(6)
    readonly property int controlCenterWidth: scaledSize(276)
    readonly property int rowSpacing: spacingXl
    readonly property int listSpacing: spacingSm
    readonly property int compactSpacing: spacingXxs
    readonly property int tightSpacing: spacingXs
    readonly property int sectionSpacing: spacingXxxl
    readonly property int radius: controlRadius
    readonly property int smallRadius: controlRadius
    readonly property int barRadius: scaledSize(styleBarRadius)
    readonly property int pillRadius: scaledSize(stylePillRadius)
    readonly property int logoRadius: scaledSize(styleLogoRadius)
    readonly property int islandPadding: styleBarIslands ? spacingLg : 0
    readonly property bool barIslandsTransparent: styleBarIslands && compositorActive
    readonly property int pillHeight: scaledSize(26)
    readonly property int pillHorizontalPadding: scaledSize(9)
    readonly property int compactWidgetSize: scaledSize(22)
    readonly property int compactWidgetHorizontalPadding: scaledSize(6)
    readonly property real networkWidgetHorizontalPadding: 4.5 * fontScale
    readonly property int pillBorderWidth: controlBorderWidth
    readonly property int animationFast: reducedMotion ? 0 : 120
    readonly property int animationNormal: reducedMotion ? 0 : 180
    readonly property int buttonHeight: controlHeight
    readonly property int chipHeight: scaledSize(28)
    readonly property int workspaceButtonSize: scaledSize(22)
    readonly property int compactButtonHeight: scaledSize(40)
    readonly property int confirmButtonHeight: scaledSize(48)
    readonly property int notificationAccentWidth: scaledSize(4)
    readonly property int notificationAccentRadius: 0
    readonly property int largeSurfaceMargin: scaledSize(22)
    readonly property int largeSurfaceNavWidth: scaledSize(248)
    readonly property int largeSurfaceSearchHeight: scaledSize(44)
    readonly property int largeSurfaceCardRadius: scaledSize(styleCardRadius)
    // Soft style search fields use a slightly heavier accent outline.
    readonly property real inputFocusBorderWidth: softStyle && !highContrast
        ? 1.5 * fontScale : controlFocusBorderWidth
    readonly property int titleFontSize: fontTitleSize
    readonly property int bodyFontSize: fontSubtitleSize
    readonly property int panelFontSize: fontBodySize
    readonly property int smallFontSize: fontBodySmallSize
    readonly property int tinyFontSize: fontCaptionSize
    readonly property int inputFontSize: scaledFontSize(16, 12)
    readonly property int iconSize: scaledSize(28)
    readonly property int trayItemSize: scaledSize(24)
    readonly property int trayIconSize: scaledSize(18)
    readonly property int closeButtonSize: scaledSize(30)
}

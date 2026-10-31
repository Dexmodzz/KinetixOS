#!/usr/bin/env python3
"""Text contrast of themes that declare shell colors (WCAG AA, 4.5:1).

Each pair names a text role and the shell surface it is drawn on. Roles fall
back to the classic palette keys the appearance provider uses, so the test
covers exactly what the shell renders.
"""

import re
import sys
import unittest
from pathlib import Path

THEMES = Path(__file__).resolve().parents[1] / "config/themes.toml"
MINIMUM = 4.5

# (text key, background key) as rendered by the Quickshell panel and popups.
PAIRS = (
    ("normfgcolor", "shell_popup"),
    ("normfgcolor", "shell_bar"),
    ("normfgcolor", "shell_window"),
    ("normfgcolor", "shell_input"),
    ("normfgcolor", "selbgcolor"),
    ("normfgcolor", "shell_chip"),
    ("shell_text_secondary", "shell_bar"),
    ("shell_text_secondary", "shell_popup"),
    ("shell_text_muted", "shell_popup"),
    ("shell_text_muted", "shell_bar"),
    ("shell_text_muted", "shell_window"),
    ("shell_text_muted", "shell_input"),
    ("shell_text_muted", "selbgcolor"),
    ("shell_text_faint", "shell_bar"),
    ("shell_on_accent", "selbordercolor"),
    ("selbordercolor", "shell_popup"),
    ("selbordercolor", "shell_bar"),
    ("term_fg", "term_bg"),
    ("term_color2", "term_bg"),
)


def themes():
    result, current = {}, None
    for line in THEMES.read_text(encoding="utf-8").splitlines():
        header = re.match(r"^\[theme\.([A-Za-z0-9._-]+)\]\s*$", line)
        if header:
            current = result.setdefault(header.group(1), {})
            continue
        if line.startswith("["):
            current = None
            continue
        value = re.match(r'^\s*([a-z_0-9]+)\s*=\s*"(#[0-9A-Fa-f]{6})"', line)
        if current is not None and value:
            current[value.group(1)] = value.group(2)
    return result


def luminance(color):
    channels = [int(color[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [
        c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in channels
    ]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(first, second):
    high, low = sorted((luminance(first), luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


class ThemeContrastTests(unittest.TestCase):
    def test_shell_themes_meet_text_contrast(self):
        checked = 0
        for name, colors in themes().items():
            if not any(key.startswith("shell_") for key in colors):
                continue
            for text, background in PAIRS:
                if text not in colors or background not in colors:
                    continue
                with self.subTest(theme=name, text=text, background=background):
                    ratio = contrast(colors[text], colors[background])
                    self.assertGreaterEqual(
                        ratio, MINIMUM, f"{name}: {text} on {background} is {ratio:.2f}:1"
                    )
                    checked += 1
        self.assertGreater(checked, 0, "no theme declares shell colors")


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    unittest.main()

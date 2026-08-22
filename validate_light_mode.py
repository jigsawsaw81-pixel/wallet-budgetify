#!/usr/bin/env python3
"""Static and numeric regression checks for Budgetify's semantic Light/Dark theme."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).parent
BUDGETIFY = ROOT / "Budgetify"
DESIGN = (BUDGETIFY / "DesignSystem.swift").read_text(encoding="utf-8")
CONTENT = (BUDGETIFY / "ContentView.swift").read_text(encoding="utf-8")
SCREENS = (BUDGETIFY / "Screens.swift").read_text(encoding="utf-8")
EDITORS = (BUDGETIFY / "Editors.swift").read_text(encoding="utf-8")


def luminance(hex_value: str) -> float:
    channels = [int(hex_value[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = [channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4 for channel in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(foreground: str, background: str) -> float:
    first, second = luminance(foreground), luminance(background)
    light, dark = max(first, second), min(first, second)
    return (light + 0.05) / (dark + 0.05)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


# Critical Light-mode text pairs must remain readable at normal and small text sizes.
require(contrast("10242B", "F3F6FA") >= 7.0, "Primary text does not meet strong Light-mode contrast on canvas")
require(contrast("38545F", "FFFFFF") >= 6.0, "Secondary text is too faint on Light-mode cards")
require(contrast("5B727C", "FFFFFF") >= 4.5, "Tertiary text is too faint on Light-mode cards")
require(contrast("F7FFFE", "092B3A") >= 10.0, "Hero balance text is not readable on the Light-mode dark card")
require(contrast("D3F6F0", "0C4651") >= 7.0, "Hero secondary text is not readable on the Light-mode dark card")
require(contrast("FFFFFF", "006F6B") >= 5.0, "Selected controls lack sufficient Light-mode contrast")
require(contrast("38545F", "E4ECF3") >= 4.5, "Unselected controls lack sufficient Light-mode contrast")

for token in (
    "canvas", "surface", "elevated", "glassSurface", "glassBorder", "glassShadow",
    "primaryText", "secondaryText", "tertiaryText", "selected", "selectedText",
    "unselected", "unselectedText", "debit", "credit", "warning", "accent",
):
    require(re.search(rf"static let {token} =", DESIGN) is not None, f"Missing semantic palette token: {token}")

# Content views must not introduce theme-blind content colors outside the palette definition.
for swift_file in BUDGETIFY.glob("*.swift"):
    if swift_file.name == "DesignSystem.swift":
        continue
    source = swift_file.read_text(encoding="utf-8")
    forbidden = re.findall(r"\.foregroundStyle\(\.(?:white|black)\)|\.foregroundColor\(\.(?:white|black)\)|Color\.(?:white|black)", source)
    require(not forbidden, f"Hard-coded content color in {swift_file.name}: {forbidden}")

require("struct HeroBalanceCard" in CONTENT and "BudgetifyPalette.heroText" in CONTENT and "BudgetifyPalette.heroGradientStart" in CONTENT, "Home balance card is not using the semantic hero surface")
require("BalanceCardSurface" in SCREENS and "BudgetifyPalette.heroText" in SCREENS, "Wallets balance card is not using the semantic hero surface")
require(CONTENT.count("budgetifyNavigationChrome()") >= 2, "Home and Transactions are missing navigation chrome")
require(SCREENS.count("budgetifyNavigationChrome()") >= 3, "Wallets and Settings are missing navigation chrome")
require(EDITORS.count("budgetifyFormChrome()") == 6, "Not every editor uses shared form chrome")
require(EDITORS.count("presentationBackground(BudgetifyPalette.canvas)") == 6, "Not every editor sheet has a semantic presentation background")
require("BudgetifyPalette.selected" in CONTENT and "BudgetifyPalette.unselected" in CONTENT, "Chip selected/unselected states are not explicit")
require("GlassButtonStyle" in EDITORS, "Calculator selected/unselected states are not explicit")
require("preferredColorScheme(settings.appearance.colorScheme)" in CONTENT or "preferredColorScheme(settings.appearance.colorScheme)" in SCREENS, "System/Light/Dark appearance propagation is missing")

print("Light-mode semantic palette, contrast, surface, navigation, form, and state checks passed.")
print("Validated System/Light/Dark source propagation and high-contrast balance cards.")
print("Validated no hard-coded white/black content colors outside DesignSystem.swift.")
print("Validated six editor sheets use shared form and presentation chrome.")

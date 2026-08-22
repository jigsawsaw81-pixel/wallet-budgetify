from pathlib import Path

ROOT = Path(__file__).parent
APP = ROOT / "Budgetify"
PROJECT = ROOT / "Wallet.xcodeproj" / "project.pbxproj"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


design = text(APP / "DesignSystem.swift")
content = text(APP / "ContentView.swift")
screens = text(APP / "Screens.swift")
editors = text(APP / "Editors.swift")
intents = text(APP / "AppIntents.swift")
store = text(APP / "BudgetifyStore.swift")
app = text(APP / "BudgetifyApp.swift")
pbx = text(PROJECT)

require("holdActionsEnabled" in design, "Hold Actions setting is missing")
require("budgetify.holdActionsEnabled" in design, "Hold Actions setting is not persisted")
require("BudgetifyHaptics" not in design and "hapticsEnabled" not in design, "Haptic implementation remains")
require("budgetifyContextMenu" in content, "Transaction context menu is missing")
require(content.count("role: .destructive") >= 2, "Transaction delete confirmation paths are missing")
require("budgetifyContextMenu(enabled: settings.holdActionsEnabled)" in screens, "Wallet/commitment context actions are not gated")
require(screens.count("budgetifyContextMenu(enabled: settings.holdActionsEnabled)") >= 3, "Wallet, recurring, and fixed hold actions are incomplete")
require("hapticsEnabled" not in screens + editors + content, "Haptic UI or call sites remain")
require("WalletAppDelegate" not in app and "quickAction" not in content, "Home Screen quick actions remain")
require("title: String, categoryID: UUID?" in store, "Optional transaction title/category store contract is missing")
require("Title (optional)" in editors and "Category (optional)" in editors, "Optional transaction fields are not visible")
require("func updateCategory" in store and "func deleteCategory" in store, "Category edit/delete methods are missing")
require("CategoryEditSheet" in screens, "Category editing UI is missing")
require("Backup merged without duplicates" in store, "Deduplicating import flow is missing")

kind = intents.index('@Parameter(title: "Paying or Receiving")')
amount = intents.index('@Parameter(title: "Amount")')
wallet = intents.index('@Parameter(title: "a/c")')
note = intents.index('@Parameter(title: "Note", default: "")')
require(kind < amount < wallet < note, "Primary guided intent parameter order is incorrect")
require('var category: BudgetifyCategoryEntity?' in intents[intents.index("struct RecordTransactionIntent"):intents.index("struct QuickAddMoneyOutIntent")], "Record Transaction requires an optional category")
require("addTransactionFromShortcut" in intents and "already appears to have been recorded" in store, "Intent duplicate protection is missing")
require("TransferMoneyIntent" not in intents[intents.index("struct BudgetifyShortcuts"):], "Transfer shortcut remains registered")

for forbidden in [
    "WidgetKit", "BudgetifyWidget", "WidgetSupport", "com.apple.security.application-groups",
    "com.apple.widgetkit-extension", "BudgetifyWidget.appex", "BudgetifyWidget.entitlements",
]:
    require(forbidden not in pbx, f"Removed extension project reference remains: {forbidden}")
require("C10000000000000000000004" not in pbx, "Removed extension embed phase remains")
require("E10000000000000000000002" not in pbx, "Removed extension target remains")
require("BudgetifyWidget" not in text(ROOT / ".github" / "workflows" / "build-ipa.yml"), "Removed extension workflow reference remains")

print("Overhaul validation passed: Wallet branding, no haptics/quick actions, optional transaction fields, categories, deduping import, guided intent order, hold actions, and no extension.")

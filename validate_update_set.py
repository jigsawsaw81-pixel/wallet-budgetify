from pathlib import Path

ROOT = Path(__file__).parent / "Budgetify"

def read(name):
    return (ROOT / name).read_text(encoding="utf-8")

design = read("DesignSystem.swift")
store = read("BudgetifyStore.swift")
content = read("ContentView.swift")
screens = read("Screens.swift")
editors = read("Editors.swift")
app = read("BudgetifyApp.swift")
intents = read("AppIntents.swift")
all_source = "\n".join((design, store, content, screens, editors, app, intents))

required = {
    "persistent settings": [
        "@Published var defaultTransactionType",
        "@Published var defaultWalletID",
        "@Published var defaultCategoryID",
    ],
    "undo and mutation helpers": [
        "func undoLastAction()",
        "func batchDeleteTransactions",
        "func duplicateTransaction",
        "func markReviewed",
        "func deleteAllDataPermanently",
    ],
    "live data refresh": [
        "budgetifyDataDidChange",
        "func reload()",
        "NotificationCenter.default.post(name: .budgetifyDataDidChange",
        "BudgetifyPersistence.makeContainer()",
    ],

    "settings control center": [
        "Appearance",
        "Currency",
        "First day of week",
        "Notifications",
        "Recurring Payments & Fixed Expenses",
        "Data & Privacy",
        "Delete all data",
        "About & Help",
    ],
    "editor defaults": [
        "settings.defaultWalletID",
        "settings.defaultCategoryID",
        "settings.showNotesByDefault",
        "settings.showPaymentMethodByDefault",
    ],
    "intent coverage": [
        "struct RecordTransactionIntent: AppIntent",
        "enum BudgetifyEntryKind: String, AppEnum",
        "struct BudgetifyWalletEntity: AppEntity",
        "struct BudgetifyGroupEntity: AppEntity",
        "struct BudgetifyCategoryEntity: AppEntity",
        "Date()",
        "MoneyFormatter.string",
        "OpenBudgetifyAddTransactionIntent",
    ],
}

for label, needles in required.items():
    for needle in needles:
        assert needle in all_source, f"missing {label} contract: {needle}"

assert screens.count("struct SettingsView: View") == 1
assert "onReceive(NotificationCenter.default.publisher(for: .budgetifyDataDidChange))" in content
assert "if newPhase == .active { store.reload() }" in content
assert "NotificationCenter.default.post(name: .budgetifyDataDidChange" in store
assert "var wallet: BudgetifyWalletEntity" in intents
assert "var group: BudgetifyGroupEntity" in intents

assert "Title (optional)" in editors
assert "Category (optional)" in editors
assert "Backup merged without duplicates" in store

print("Update-set validation passed: persistent settings, simplified Settings, optional transaction fields, deduplicating import, App Intents, undo/delete controls, live refresh, and editor defaults.")

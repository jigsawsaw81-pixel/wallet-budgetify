import AppIntents
import SwiftData

struct BudgetifyIntentError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum BudgetifyEntryKind: String, AppEnum {
    case debit
    case credit

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Entry type")
    static var caseDisplayRepresentations: [BudgetifyEntryKind: DisplayRepresentation] = [
        .debit: DisplayRepresentation(title: "Money Out", subtitle: "Money leaving an a/c"),
        .credit: DisplayRepresentation(title: "Money In", subtitle: "Money entering an a/c")
    ]

    var transactionType: TransactionType { self == .credit ? .income : .expense }
    var categoryType: CategoryType { self == .credit ? .income : .expense }
    var title: String { self == .credit ? "Money In" : "Money Out" }
}

struct BudgetifyWalletEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "a/c")
    static var defaultQuery = BudgetifyWalletQuery()

    let id: String
    let name: String
    let groupName: String
    let balance: Decimal

    init(wallet: Wallet, groupName: String, balance: Decimal) {
        id = wallet.id.uuidString
        name = wallet.name
        self.groupName = groupName
        self.balance = balance
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name), subtitle: LocalizedStringResource(stringLiteral: "\(groupName) · \(MoneyFormatter.string(balance))"))
    }
}

struct BudgetifyGroupEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "a/c group")
    static var defaultQuery = BudgetifyGroupQuery()

    let id: String
    let name: String
    let balance: Decimal

    init(group: AccountGroup, balance: Decimal) {
        id = group.id.uuidString
        name = group.label
        self.balance = balance
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name), subtitle: LocalizedStringResource(stringLiteral: MoneyFormatter.string(balance)))
    }
}

struct BudgetifyCategoryEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Category")
    static var defaultQuery = BudgetifyCategoryQuery()

    let id: String
    let name: String
    let type: CategoryType

    init(category: BudgetCategory) {
        id = category.id.uuidString
        name = category.name
        type = category.type
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name), subtitle: LocalizedStringResource(stringLiteral: type.title))
    }
}

@MainActor
enum BudgetifyIntentSupport {
    private static let sharedContainer = BudgetifyPersistence.makeContainer()

    static func makeStore() throws -> BudgetifyStore {
        BudgetifyStore(modelContext: sharedContainer.mainContext)
    }

    static func uuid(_ value: String, label: String) throws -> UUID {
        guard let id = UUID(uuidString: value) else {
            throw BudgetifyIntentError(message: "The selected \(label.lowercased()) is no longer available.")
        }
        return id
    }

    static func amount(_ value: Decimal) throws -> Decimal {
        guard value > 0 else { throw BudgetifyIntentError(message: "Enter an amount greater than zero.") }
        return value
    }

    static func decimalAmount(_ value: Double) throws -> Decimal {
        guard value.isFinite else { throw BudgetifyIntentError(message: "Enter a valid INR amount.") }
        guard let decimal = Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) else {
            throw BudgetifyIntentError(message: "Enter a valid INR amount.")
        }
        return try amount(decimal)
    }

    static func amount(_ raw: String) throws -> Decimal {
        guard case let .success(value) = MoneyParser.parse(raw) else {
            throw BudgetifyIntentError(message: "Enter a valid positive INR amount.")
        }
        return value
    }

    static func wallet(_ entity: BudgetifyWalletEntity, in store: BudgetifyStore) throws -> Wallet {
        let id = try uuid(entity.id, label: "wallet")
        guard let wallet = store.wallets.first(where: { $0.id == id }) else {
            throw BudgetifyIntentError(message: "The selected wallet is no longer available.")
        }
        return wallet
    }

    static func group(_ entity: BudgetifyGroupEntity, in store: BudgetifyStore) throws -> AccountGroup {
        let id = try uuid(entity.id, label: "account or group")
        guard let group = store.groups.first(where: { $0.id == id }) else {
            throw BudgetifyIntentError(message: "The selected account or group is no longer available.")
        }
        return group
    }

    static func category(_ entity: BudgetifyCategoryEntity, kind: BudgetifyEntryKind, in store: BudgetifyStore) throws -> BudgetCategory {
        let id = try uuid(entity.id, label: "category")
        guard let category = store.categories.first(where: { $0.id == id && $0.type == kind.categoryType }) else {
            throw BudgetifyIntentError(message: "Choose a category that matches the selected entry type.")
        }
        return category
    }

    static func validate(wallet: Wallet, group: AccountGroup, in store: BudgetifyStore) throws {
        guard wallet.groupID == group.id else {
            throw BudgetifyIntentError(message: "Choose an a/c group that contains the selected a/c.")
        }
        guard store.wallets.contains(where: { $0.id == wallet.id }) else {
            throw BudgetifyIntentError(message: "The selected a/c is no longer available.")
        }
    }

    static func confirmation(type: BudgetifyEntryKind, amount: Decimal, wallet: Wallet, category: BudgetCategory?, date: Date, note: String?) -> String {
        let timestamp = date.formatted(date: .abbreviated, time: .shortened)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let noteText = trimmedNote.isEmpty ? "" : " Note: \(trimmedNote)"
        let categoryText = category?.name ?? "the default category"
        return "\(type.title) recorded: \(MoneyFormatter.string(amount)) in \(wallet.name), \(categoryText), at \(timestamp).\(noteText)"
    }
}

struct BudgetifyWalletQuery: EntityQuery {
    func entities(for identifiers: [BudgetifyWalletEntity.ID]) async throws -> [BudgetifyWalletEntity] {
        try await MainActor.run {
            let store = try BudgetifyIntentSupport.makeStore()
            return identifiers.compactMap { id in
                guard let uuid = UUID(uuidString: id), let wallet = store.wallets.first(where: { $0.id == uuid }) else { return nil }
                return BudgetifyWalletEntity(wallet: wallet, groupName: store.group(for: wallet)?.label ?? "Account", balance: store.balance(for: wallet))
            }
        }
    }

    func suggestedEntities() async throws -> [BudgetifyWalletEntity] {
        try await MainActor.run {
            let store = try BudgetifyIntentSupport.makeStore()
            return store.wallets.map { BudgetifyWalletEntity(wallet: $0, groupName: store.group(for: $0)?.label ?? "Account", balance: store.balance(for: $0)) }
        }
    }
}

struct BudgetifyGroupQuery: EntityQuery {
    func entities(for identifiers: [BudgetifyGroupEntity.ID]) async throws -> [BudgetifyGroupEntity] {
        try await MainActor.run {
            let store = try BudgetifyIntentSupport.makeStore()
            return identifiers.compactMap { id in
                guard let uuid = UUID(uuidString: id), let group = store.groups.first(where: { $0.id == uuid }) else { return nil }
                return BudgetifyGroupEntity(group: group, balance: store.balance(for: group))
            }
        }
    }

    func suggestedEntities() async throws -> [BudgetifyGroupEntity] {
        try await MainActor.run {
            let store = try BudgetifyIntentSupport.makeStore()
            return store.groups.map { BudgetifyGroupEntity(group: $0, balance: store.balance(for: $0)) }
        }
    }
}

struct BudgetifyCategoryQuery: EntityQuery {
    func entities(for identifiers: [BudgetifyCategoryEntity.ID]) async throws -> [BudgetifyCategoryEntity] {
        try await MainActor.run {
            let store = try BudgetifyIntentSupport.makeStore()
            return identifiers.compactMap { id in
                guard let uuid = UUID(uuidString: id), let category = store.categories.first(where: { $0.id == uuid }) else { return nil }
                return BudgetifyCategoryEntity(category: category)
            }
        }
    }

    func suggestedEntities() async throws -> [BudgetifyCategoryEntity] {
        try await MainActor.run {
            let store = try BudgetifyIntentSupport.makeStore()
            return store.categories.filter { $0.type == .expense || $0.type == .income }.map(BudgetifyCategoryEntity.init)
        }
    }
}

struct BudgetifyCategoryOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<RecordTransactionIntent>(\.$kind) var intent

    func results() async throws -> [BudgetifyCategoryEntity] {
        try await MainActor.run {
            let store = try BudgetifyIntentSupport.makeStore()
            let type = intent?.kind.categoryType ?? .expense
            return store.categories.filter { $0.type == type }.map(BudgetifyCategoryEntity.init)
        }
    }
}

struct BudgetifyDebitCategoryOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [BudgetifyCategoryEntity] {
        try await MainActor.run {
            let store = try BudgetifyIntentSupport.makeStore()
            return store.categories.filter { $0.type == .expense }.map(BudgetifyCategoryEntity.init)
        }
    }
}

struct BudgetifyCreditCategoryOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [BudgetifyCategoryEntity] {
        try await MainActor.run {
            let store = try BudgetifyIntentSupport.makeStore()
            return store.categories.filter { $0.type == .income }.map(BudgetifyCategoryEntity.init)
        }
    }
}

struct RecordTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Record transaction"
    static var description = IntentDescription("Record a Wallet Money In or Money Out with an amount, a/c, optional category, and optional note.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Paying or Receiving") var kind: BudgetifyEntryKind
    @Parameter(title: "Amount") var amount: Double
    @Parameter(title: "a/c") var wallet: BudgetifyWalletEntity
    @Parameter(title: "Category") var category: BudgetifyCategoryEntity?
    @Parameter(title: "Note", default: "") var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("Record \(\.$kind) of \(\.$amount) in \(\.$wallet)") {
            \.$category
            \.$note
        }
    }

    func perform() async throws -> some IntentResult {
        let selectedKind = kind
        let selectedAmount = amount
        let selectedWallet = wallet
        let selectedCategory = category
        let selectedNote = note
        let now = Date()

        let dialog = try await MainActor.run {
            let store = try BudgetifyIntentSupport.makeStore()
            let appSettings = AppSettings()
            let value = try BudgetifyIntentSupport.decimalAmount(selectedAmount)
            let targetWallet = try BudgetifyIntentSupport.wallet(selectedWallet, in: store)
            let chosenCategory = appSettings.shortcutIncludesCategory ? selectedCategory : nil
            let targetCategory = try chosenCategory.map { try BudgetifyIntentSupport.category($0, kind: selectedKind, in: store) }
            let chosenNote = appSettings.shortcutIncludesNote ? selectedNote : ""
            try store.addTransactionFromShortcut(amount: value, title: nil, categoryID: targetCategory?.id, walletID: targetWallet.id, type: selectedKind.transactionType, notes: chosenNote.isEmpty ? nil : chosenNote, date: now)
            return BudgetifyIntentSupport.confirmation(type: selectedKind, amount: value, wallet: targetWallet, category: targetCategory, date: now, note: chosenNote)
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct QuickAddMoneyOutIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick add Money Out"
    static var description = IntentDescription("Add Money Out with selectable a/c, category, amount, and optional note.")
    static var openAppWhenRun = false

    @Parameter(title: "Amount") var amount: Double
    @Parameter(title: "a/c") var wallet: BudgetifyWalletEntity
    @Parameter(title: "Category", optionsProvider: BudgetifyDebitCategoryOptionsProvider()) var category: BudgetifyCategoryEntity
    @Parameter(title: "Note", default: "") var note: String

    func perform() async throws -> some IntentResult {
        let rawAmount = amount
        let decimalAmount = try await MainActor.run { try BudgetifyIntentSupport.decimalAmount(rawAmount) }
        return try await BudgetifyIntentSupport.record(kind: .debit, amount: decimalAmount, wallet: wallet, category: category, note: note)
    }
}

struct QuickAddMoneyInIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick add Money In"
    static var description = IntentDescription("Add Money In with selectable a/c, category, amount, and optional note.")
    static var openAppWhenRun = false

    @Parameter(title: "Amount") var amount: Double
    @Parameter(title: "a/c") var wallet: BudgetifyWalletEntity
    @Parameter(title: "Category", optionsProvider: BudgetifyCreditCategoryOptionsProvider()) var category: BudgetifyCategoryEntity
    @Parameter(title: "Note", default: "") var note: String

    func perform() async throws -> some IntentResult {
        let rawAmount = amount
        let decimalAmount = try await MainActor.run { try BudgetifyIntentSupport.decimalAmount(rawAmount) }
        return try await BudgetifyIntentSupport.record(kind: .credit, amount: decimalAmount, wallet: wallet, category: category, note: note)
    }
}



extension BudgetifyIntentSupport {
    static func record(kind: BudgetifyEntryKind, amount: Decimal, wallet: BudgetifyWalletEntity, category: BudgetifyCategoryEntity, note: String) async throws -> some IntentResult {
        let dialog = try await MainActor.run {
            let store = try makeStore()
            let now = Date()
            let value = try self.amount(amount)
            let targetWallet = try self.wallet(wallet, in: store)
            let targetCategory = try self.category(category, kind: kind, in: store)
            try store.addTransactionFromShortcut(amount: value, title: targetCategory.name, categoryID: targetCategory.id, walletID: targetWallet.id, type: kind.transactionType, notes: note, date: now)
            return confirmation(type: kind, amount: value, wallet: targetWallet, category: targetCategory, date: now, note: note)
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct ShowTotalBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Show total balance"
    static var description = IntentDescription("Show the current Wallet balance across all a/c groups.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let value = try await MainActor.run { try BudgetifyIntentSupport.makeStore().grandTotal }
        return .result(dialog: IntentDialog(stringLiteral: "Total a/c balance: \(MoneyFormatter.string(value))."))
    }
}

struct ShowWalletBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Show a/c balance"
    static var description = IntentDescription("Show the current balance for a selected Wallet a/c.")
    static var openAppWhenRun = false
    @Parameter(title: "a/c") var wallet: BudgetifyWalletEntity

    func perform() async throws -> some IntentResult {
        let entity = wallet
        let dialog = try await MainActor.run {
            let store = try BudgetifyIntentSupport.makeStore()
            let target = try BudgetifyIntentSupport.wallet(entity, in: store)
            return "\(target.name) balance: \(MoneyFormatter.string(store.balance(for: target)))."
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct ShowGroupBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Show account balance"
    static var description = IntentDescription("Show the current balance for a selected Wallet account or group.")
    static var openAppWhenRun = false
    @Parameter(title: "Account or Group") var group: BudgetifyGroupEntity

    func perform() async throws -> some IntentResult {
        let entity = group
        let dialog = try await MainActor.run {
            let store = try BudgetifyIntentSupport.makeStore()
            let target = try BudgetifyIntentSupport.group(entity, in: store)
            return "\(target.label) balance: \(MoneyFormatter.string(store.balance(for: target)))."
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct ShowTodaySpendingIntent: AppIntent {
    static var title: LocalizedStringResource = "Show today’s spending"
    static var description = IntentDescription("Show Money Out spending recorded today in Wallet.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let value = try await MainActor.run { try BudgetifyIntentSupport.makeStore().todayExpense }
        return .result(dialog: IntentDialog(stringLiteral: "Today’s spending: \(MoneyFormatter.string(value))."))
    }
}

struct ShowMonthSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Show this month’s summary"
    static var description = IntentDescription("Show this month’s Wallet Money In, Money Out, and net.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let result = try await MainActor.run { () -> String in
            let store = try BudgetifyIntentSupport.makeStore()
            return "This month: Money In \(MoneyFormatter.string(store.monthIncome)), Money Out \(MoneyFormatter.string(store.monthExpense)), net \(MoneyFormatter.string(store.monthNet))."
        }
        return .result(dialog: IntentDialog(stringLiteral: result))
    }
}

struct ShowRecentTransactionsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show recent transactions"
    static var description = IntentDescription("Read the five newest Wallet transactions.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let result = try await MainActor.run { () -> String in
            let store = try BudgetifyIntentSupport.makeStore()
            guard !store.transactions.isEmpty else { return "There are no recent transactions." }
            let lines = store.transactions.prefix(5).map { transaction in
                let sign = transaction.type == .income ? "+" : "−"
                return "\(transaction.title), \(sign)\(MoneyFormatter.string(transaction.amount)), \(transaction.createdAt.formatted(date: .abbreviated, time: .shortened))"
            }
            return "Recent transactions: " + lines.joined(separator: "; ")
        }
        return .result(dialog: IntentDialog(stringLiteral: result))
    }
}

struct ShowUpcomingCommitmentsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show upcoming commitments"
    static var description = IntentDescription("Show active recurring payments and fixed expenses in Wallet.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let result = try await MainActor.run { () -> String in
            let store = try BudgetifyIntentSupport.makeStore()
            let recurring = store.recurringPayments.filter(\.isActive).map { "\($0.name), \(MoneyFormatter.string($0.amount))" }
            let fixed = store.fixedExpenses.filter(\.isActive).map { "\($0.name), \(MoneyFormatter.string($0.amount))" }
            let all = recurring + fixed
            return all.isEmpty ? "There are no upcoming commitments." : "Upcoming commitments: " + all.joined(separator: "; ")
        }
        return .result(dialog: IntentDialog(stringLiteral: result))
    }
}

struct OpenBudgetifyAddTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Wallet add transaction"
    static var description = IntentDescription("Open Wallet so you can add a transaction.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result(dialog: IntentDialog(stringLiteral: "Wallet is ready for a new transaction."))
    }
}

struct BudgetifyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RecordTransactionIntent(), phrases: ["Log a transaction in \(.applicationName)", "Record an expense in \(.applicationName)", "Record income in \(.applicationName)"], shortTitle: "Record transaction", systemImageName: "plus.circle")
        AppShortcut(intent: ShowTotalBalanceIntent(), phrases: ["Show total balance in \(.applicationName)"], shortTitle: "Total balance", systemImageName: "sum")
        AppShortcut(intent: ShowWalletBalanceIntent(), phrases: ["Show wallet balance in \(.applicationName)"], shortTitle: "Wallet balance", systemImageName: "wallet.pass")
        AppShortcut(intent: ShowTodaySpendingIntent(), phrases: ["Show today’s spending in \(.applicationName)"], shortTitle: "Today’s spending", systemImageName: "calendar")
        AppShortcut(intent: ShowMonthSummaryIntent(), phrases: ["Show this month’s summary in \(.applicationName)"], shortTitle: "Month summary", systemImageName: "chart.bar")
        AppShortcut(intent: ShowRecentTransactionsIntent(), phrases: ["Show recent transactions in \(.applicationName)"], shortTitle: "Recent transactions", systemImageName: "list.bullet")
        AppShortcut(intent: ShowUpcomingCommitmentsIntent(), phrases: ["Show upcoming commitments in \(.applicationName)"], shortTitle: "Upcoming commitments", systemImageName: "calendar.badge.clock")
    }
}

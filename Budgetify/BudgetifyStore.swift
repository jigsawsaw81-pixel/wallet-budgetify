import Foundation
import SwiftData
import Combine

extension Notification.Name {
    static let budgetifyDataDidChange = Notification.Name("budgetify.dataDidChange")
}

private struct TransactionUndoSnapshot {
    let id: UUID
    let amount: Decimal
    let title: String
    let categoryID: UUID
    let walletID: UUID
    let type: TransactionType
    let status: PaymentStatus?
    let paymentMethod: String?
    let notes: String?
    let createdAt: Date
}

private struct RecurringUndoSnapshot {
    let id: UUID
    let name: String
    let amount: Decimal
    let dayOfMonth: Int
    let walletID: UUID
    let categoryID: UUID
    let kind: RecurringKind
    let isActive: Bool
    let createdAt: Date
}

private struct FixedUndoSnapshot {
    let id: UUID
    let name: String
    let amount: Decimal
    let frequency: FixedFrequency
    let walletID: UUID
    let categoryID: UUID
    let isActive: Bool
    let createdAt: Date
}

private struct WalletUndoSnapshot {
    let id: UUID
    let name: String
    let initialBalance: Decimal
    let colorHex: String
    let symbol: String
    let kind: WalletKind
    let groupID: UUID
    let createdAt: Date
}

private enum UndoPayload {
    case transaction(TransactionUndoSnapshot)
    case transactions([TransactionUndoSnapshot])
    case recurring(RecurringUndoSnapshot)
    case fixed(FixedUndoSnapshot)
    case wallet(WalletUndoSnapshot)
}

@MainActor
final class BudgetifyStore: ObservableObject {
    let modelContext: ModelContext

    @Published private(set) var groups: [AccountGroup] = []
    @Published private(set) var wallets: [Wallet] = []
    @Published private(set) var categories: [BudgetCategory] = []
    @Published private(set) var transactions: [BudgetTransaction] = []
    @Published private(set) var recurringPayments: [RecurringPayment] = []
    @Published private(set) var fixedExpenses: [FixedExpense] = []
    @Published var selectedWalletID: UUID?
    @Published var query = ""
    @Published var transactionFilter: TransactionFilter = .all
    @Published var dateFilter: DateFilter = .all
    @Published var categoryFilter: UUID?
    @Published var isShowingError = false
    @Published var errorMessage = ""
    @Published var isShowingSuccess = false
    @Published var successMessage = ""
    @Published private(set) var canUndo = false
    private var undoPayload: UndoPayload?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        seedIfNeeded()
        refresh()
    }

    func reload() {
        refresh()
    }

    func refresh() {
        do {
            groups = try modelContext.fetch(FetchDescriptor<AccountGroup>(sortBy: [SortDescriptor(\AccountGroup.sortOrder)]))
            wallets = try modelContext.fetch(FetchDescriptor<Wallet>(sortBy: [SortDescriptor(\Wallet.createdAt)]))
            categories = try modelContext.fetch(FetchDescriptor<BudgetCategory>(sortBy: [SortDescriptor(\BudgetCategory.createdAt)]))
            transactions = try modelContext.fetch(FetchDescriptor<BudgetTransaction>(sortBy: [SortDescriptor(\BudgetTransaction.createdAt, order: .reverse)]))
            recurringPayments = try modelContext.fetch(FetchDescriptor<RecurringPayment>(sortBy: [SortDescriptor(\RecurringPayment.createdAt, order: .reverse)]))
            fixedExpenses = try modelContext.fetch(FetchDescriptor<FixedExpense>(sortBy: [SortDescriptor(\FixedExpense.createdAt, order: .reverse)]))
            if selectedWalletID == nil || !wallets.contains(where: { $0.id == selectedWalletID }) {
                selectedWalletID = wallets.first?.id
            }
        } catch {
            report(error)
        }
    }

    private func seedIfNeeded() {
        do {
            guard try modelContext.fetch(FetchDescriptor<AccountGroup>()).isEmpty else { return }
            let mine = UUID()
            let others = UUID()
            let work = UUID()
            [
                AccountGroup(id: mine, label: "Mine", colorHex: "00D2C8", symbol: "person.fill", sortOrder: 0),
                AccountGroup(id: others, label: "Others", colorHex: "FFB340", symbol: "person.2.fill", sortOrder: 1),
                AccountGroup(id: work, label: "Work", colorHex: "10D98A", symbol: "briefcase.fill", sortOrder: 2)
            ].forEach(modelContext.insert)
            modelContext.insert(Wallet(name: "Main Bank", colorHex: "00D2C8", symbol: "building.columns.fill", kind: .bank, groupID: mine))
            let defaults: [(String, String, String, CategoryType)] = [
                ("Food", "FFB340", "fork.knife", .expense),
                ("Shopping", "FF5C6A", "bag.fill", .expense),
                ("Transport", "00D2C8", "car.fill", .expense),
                ("Housing", "A78BFA", "house.fill", .expense),
                ("Salary", "10D98A", "briefcase.fill", .income),
                ("EMIs", "00D2C8", "calendar.badge.clock", .recurring),
                ("Subscriptions", "FFB340", "play.rectangle.fill", .recurring),
                ("Other", "7BAABB", "ellipsis.circle.fill", .expense)
            ]
            defaults.forEach { modelContext.insert(BudgetCategory(name: $0.0, colorHex: $0.1, symbol: $0.2, type: $0.3)) }
            try modelContext.save()
        } catch {
            report(error)
        }
    }

    // MARK: - Derived accounting

    func balance(for wallet: Wallet) -> Decimal {
        let movement = transactions
            .filter { $0.walletID == wallet.id && $0.status != .pending }
            .reduce(Decimal.zero) { partial, transaction in
                transaction.type == .income ? partial + transaction.amount : partial - transaction.amount
            }
        return wallet.initialBalance + movement
    }

    func balance(for group: AccountGroup) -> Decimal {
        wallets.filter { $0.groupID == group.id }.reduce(Decimal.zero) { $0 + balance(for: $1) }
    }

    var mineBankBalance: Decimal { balanceForGroup(label: "Mine", kind: .bank) }
    var mineCashBalance: Decimal { balanceForGroup(label: "Mine", kind: .cash) }
    var mineTotalBalance: Decimal { mineBankBalance + mineCashBalance }
    var workBalance: Decimal { balanceForGroup(label: "Work", kind: nil) }
    var othersBalance: Decimal { balanceForGroup(label: "Others", kind: nil) }
    var grandTotal: Decimal { mineTotalBalance + workBalance + othersBalance }

    var currentMonthTransactions: [BudgetTransaction] {
        transactions.filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month) }
    }

    var monthIncome: Decimal { currentMonthTransactions.filter { $0.type == .income && $0.status != .pending }.reduce(Decimal.zero) { $0 + $1.amount } }
    var monthExpense: Decimal { currentMonthTransactions.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount } }
    var monthNet: Decimal { monthIncome - monthExpense }
    var pendingIncome: Decimal { transactions.filter { $0.type == .income && $0.status == .pending }.reduce(Decimal.zero) { $0 + $1.amount } }
    var recurringTotal: Decimal { recurringPayments.filter(\.isActive).reduce(Decimal.zero) { $0 + $1.amount } }
    var fixedTotal: Decimal { fixedExpenses.filter(\.isActive).reduce(Decimal.zero) { $0 + $1.amount } }
    var forecast: Decimal { grandTotal + pendingIncome - recurringTotal - fixedTotal }
    var todayExpense: Decimal { transactions.filter { $0.type == .expense && Calendar.current.isDateInToday($0.createdAt) }.reduce(Decimal.zero) { $0 + $1.amount } }

    var filteredTransactions: [BudgetTransaction] {
        let now = Date()
        let calendar = Calendar.current
        return transactions.filter { transaction in
            let typeMatches = matchesType(transaction)
            let queryValue = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let queryMatches = queryValue.isEmpty || transaction.title.localizedCaseInsensitiveContains(queryValue) || category(for: transaction)?.name.localizedCaseInsensitiveContains(queryValue) == true
            let categoryMatches = categoryFilter == nil || transaction.categoryID == categoryFilter
            let dateMatches = matchesDate(transaction, calendar: calendar, now: now)
            return typeMatches && queryMatches && categoryMatches && dateMatches
        }
    }

    private func matchesType(_ transaction: BudgetTransaction) -> Bool {
        switch transactionFilter {
        case .all: return true
        case .debits: return transaction.type == .expense
        case .credits: return transaction.type == .income
        }
    }

    private func matchesDate(_ transaction: BudgetTransaction, calendar: Calendar, now: Date) -> Bool {
        switch dateFilter {
        case .all: return true
        case .today: return calendar.isDateInToday(transaction.createdAt)
        case .sevenDays:
            guard let start = calendar.date(byAdding: .day, value: -7, to: now) else { return false }
            return transaction.createdAt >= start
        case .thirtyDays:
            guard let start = calendar.date(byAdding: .day, value: -30, to: now) else { return false }
            return transaction.createdAt >= start
        }
    }

    func category(for transaction: BudgetTransaction) -> BudgetCategory? { categories.first { $0.id == transaction.categoryID } }
    func wallet(for transaction: BudgetTransaction) -> Wallet? { wallets.first { $0.id == transaction.walletID } }
    func group(for wallet: Wallet) -> AccountGroup? { groups.first { $0.id == wallet.groupID } }

    func transactions(for group: TransactionGroup) -> [BudgetTransaction] {
        let calendar = Calendar.current
        return filteredTransactions.filter { transaction in
            switch group {
            case .today:
                return calendar.isDateInToday(transaction.createdAt)
            case .yesterday:
                guard let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) else { return false }
                return calendar.isDate(transaction.createdAt, inSameDayAs: yesterday)
            case .thisWeek:
                guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) else { return false }
                return transaction.createdAt >= weekAgo && !calendar.isDateInToday(transaction.createdAt)
            case .older:
                guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) else { return false }
                return transaction.createdAt < weekAgo
            }
        }
    }

    // MARK: - Mutations

    func addTransaction(amount: Decimal, title: String, categoryID: UUID?, walletID: UUID, type: TransactionType, status: PaymentStatus? = nil, paymentMethod: String? = nil, notes: String? = nil, date: Date = .now) {
        guard amount > 0 else { reportMessage("Amount must be greater than zero."); return }
        guard let wallet = wallets.first(where: { $0.id == walletID }) else { reportMessage("Choose a valid a/c."); return }
        guard let category = resolvedTransactionCategory(categoryID, type: type) else { reportMessage("Add a matching category in Settings first."); return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (type == .income ? "Money In" : "Money Out") : title.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(BudgetTransaction(amount: amount, title: cleanTitle, categoryID: category.id, walletID: wallet.id, type: type, status: status, paymentMethod: paymentMethod, notes: notes, createdAt: date))
        persist(success: type == .income ? "Money In saved" : "Money Out saved")
    }

    func addTransactionFromShortcut(amount: Decimal, title: String?, categoryID: UUID?, walletID: UUID, type: TransactionType, notes: String?, date: Date, executionID: String? = nil) throws {
        guard amount > 0 else { throw BudgetifyIntentError(message: "Amount must be greater than zero.") }
        guard let wallet = wallets.first(where: { $0.id == walletID }) else { throw BudgetifyIntentError(message: "Choose a valid a/c.") }
        guard let category = resolvedTransactionCategory(categoryID, type: type) else { throw BudgetifyIntentError(message: "Add a matching category in Settings first.") }
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? title!.trimmingCharacters(in: .whitespacesAndNewlines) : (type == .income ? "Money In" : "Money Out")
        guard !transactions.contains(where: { existing in
            existing.type == type && existing.amount == amount && existing.categoryID == category.id && existing.walletID == wallet.id && existing.notes == notes && abs(existing.createdAt.timeIntervalSince(date)) < 90
        }) else { throw BudgetifyIntentError(message: "This transaction already appears to have been recorded.") }
        let transaction = BudgetTransaction(amount: amount, title: cleanTitle, categoryID: category.id, walletID: wallet.id, type: type, status: nil, paymentMethod: nil, notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: date)
        modelContext.insert(transaction)
        do {
            try modelContext.save()
            refresh()
            NotificationCenter.default.post(name: .budgetifyDataDidChange, object: nil)
        } catch {
            modelContext.delete(transaction)
            throw error
        }
    }

    func transferFromShortcut(from: Wallet, to: Wallet, amount: Decimal, date: Date = .now, note: String? = nil) throws {
        guard amount > 0 else { throw BudgetifyIntentError(message: "Transfer amount must be greater than zero.") }
        guard from.id != to.id else { throw BudgetifyIntentError(message: "Choose two different a/cs.") }
        guard wallets.contains(where: { $0.id == from.id }), wallets.contains(where: { $0.id == to.id }) else { throw BudgetifyIntentError(message: "Choose valid source and destination a/cs.") }
        guard groups.contains(where: { $0.id == from.groupID }), groups.contains(where: { $0.id == to.groupID }) else { throw BudgetifyIntentError(message: "Both a/cs must belong to an account or group.") }
        guard balance(for: from) >= amount else { throw BudgetifyIntentError(message: "The source a/c does not have enough available balance.") }
        guard let category = categories.first(where: { $0.name.caseInsensitiveCompare("Other") == .orderedSame }) else { throw BudgetifyIntentError(message: "A transfer category is unavailable.") }
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let duplicate = transactions.contains { existing in
            existing.paymentMethod == "Internal transfer" && existing.amount == amount && existing.walletID == from.id && existing.notes == cleanNote && abs(existing.createdAt.timeIntervalSince(date)) < 90
        }
        guard !duplicate else { throw BudgetifyIntentError(message: "This transfer already appears to have been completed.") }
        let outgoing = BudgetTransaction(amount: amount, title: "Transfer to \(to.name)", categoryID: category.id, walletID: from.id, type: .expense, status: .received, paymentMethod: "Internal transfer", notes: cleanNote, createdAt: date)
        let incoming = BudgetTransaction(amount: amount, title: "Transfer from \(from.name)", categoryID: category.id, walletID: to.id, type: .income, status: .received, paymentMethod: "Internal transfer", notes: cleanNote, createdAt: date)
        modelContext.insert(outgoing)
        modelContext.insert(incoming)
        do {
            try modelContext.save()
            refresh()
            NotificationCenter.default.post(name: .budgetifyDataDidChange, object: nil)
        } catch {
            modelContext.delete(outgoing)
            modelContext.delete(incoming)
            throw error
        }
    }

    func updateTransaction(_ transaction: BudgetTransaction, amount: Decimal, title: String, categoryID: UUID?, walletID: UUID, type: TransactionType, status: PaymentStatus?, paymentMethod: String?, notes: String? = nil, date: Date? = nil) {
        guard amount > 0 else { reportMessage("Amount must be greater than zero."); return }
        guard let category = resolvedTransactionCategory(categoryID, type: type) else { reportMessage("Add a matching category in Settings first."); return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (type == .income ? "Money In" : "Money Out") : title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard wallets.contains(where: { $0.id == walletID }) else { reportMessage("Choose a valid a/c."); return }
        transaction.amount = amount
        transaction.title = cleanTitle
        transaction.categoryID = category.id
        transaction.walletID = walletID
        transaction.type = type
        transaction.status = status
        transaction.paymentMethod = paymentMethod
        transaction.notes = notes
        if let date { transaction.createdAt = date }
        persist(success: "Transaction updated")
    }

    func deleteTransaction(_ transaction: BudgetTransaction, allowsUndo: Bool = true) {
        let snapshot = TransactionUndoSnapshot(id: transaction.id, amount: transaction.amount, title: transaction.title, categoryID: transaction.categoryID, walletID: transaction.walletID, type: transaction.type, status: transaction.status, paymentMethod: transaction.paymentMethod, notes: transaction.notes, createdAt: transaction.createdAt)
        modelContext.delete(transaction)
        persist(success: "Transaction deleted", undo: allowsUndo ? .transaction(snapshot) : nil)
    }

    func deleteTransactions(_ transactionsToDelete: [BudgetTransaction], allowsUndo: Bool = true) {
        batchDeleteTransactions(transactionsToDelete, allowsUndo: allowsUndo)
    }

    func batchDeleteTransactions(_ transactionsToDelete: [BudgetTransaction], allowsUndo: Bool = true) {
        guard !transactionsToDelete.isEmpty else { return }
        let snapshots = transactionsToDelete.map { transaction in
            TransactionUndoSnapshot(id: transaction.id, amount: transaction.amount, title: transaction.title, categoryID: transaction.categoryID, walletID: transaction.walletID, type: transaction.type, status: transaction.status, paymentMethod: transaction.paymentMethod, notes: transaction.notes, createdAt: transaction.createdAt)
        }
        transactionsToDelete.forEach { modelContext.delete($0) }
        persist(success: "\(transactionsToDelete.count) transactions deleted", undo: allowsUndo ? .transactions(snapshots) : nil)
    }

    func duplicateTransaction(_ transaction: BudgetTransaction) {
        let duplicate = BudgetTransaction(amount: transaction.amount, title: "Copy of \(transaction.title)", categoryID: transaction.categoryID, walletID: transaction.walletID, type: transaction.type, status: transaction.status, paymentMethod: transaction.paymentMethod, notes: transaction.notes, createdAt: .now)
        modelContext.insert(duplicate)
        persist(success: "Transaction duplicated")
    }

    func markReviewed(_ transaction: BudgetTransaction) {
        var reviewed = Set(UserDefaults.standard.stringArray(forKey: "budgetify.reviewedTransactionIDs") ?? [])
        reviewed.insert(transaction.id.uuidString)
        UserDefaults.standard.set(Array(reviewed), forKey: "budgetify.reviewedTransactionIDs")
        persist(success: "Transaction marked as reviewed")
    }

    func isReviewed(_ transaction: BudgetTransaction) -> Bool {
        (UserDefaults.standard.stringArray(forKey: "budgetify.reviewedTransactionIDs") ?? []).contains(transaction.id.uuidString)
    }

    func deleteRecurring(_ payment: RecurringPayment) {
        let snapshot = RecurringUndoSnapshot(id: payment.id, name: payment.name, amount: payment.amount, dayOfMonth: payment.dayOfMonth, walletID: payment.walletID, categoryID: payment.categoryID, kind: payment.kind, isActive: payment.isActive, createdAt: payment.createdAt)
        modelContext.delete(payment)
        persist(success: "Recurring payment deleted", undo: .recurring(snapshot))
    }

    func duplicateRecurring(_ payment: RecurringPayment) {
        modelContext.insert(RecurringPayment(name: "Copy of \(payment.name)", amount: payment.amount, dayOfMonth: payment.dayOfMonth, walletID: payment.walletID, categoryID: payment.categoryID, kind: payment.kind, isActive: payment.isActive))
        persist(success: "Recurring payment duplicated")
    }

    func deleteFixed(_ expense: FixedExpense) {
        let snapshot = FixedUndoSnapshot(id: expense.id, name: expense.name, amount: expense.amount, frequency: expense.frequency, walletID: expense.walletID, categoryID: expense.categoryID, isActive: expense.isActive, createdAt: expense.createdAt)
        modelContext.delete(expense)
        persist(success: "Fixed expense deleted", undo: .fixed(snapshot))
    }

    func duplicateFixed(_ expense: FixedExpense) {
        modelContext.insert(FixedExpense(name: "Copy of \(expense.name)", amount: expense.amount, frequency: expense.frequency, walletID: expense.walletID, categoryID: expense.categoryID, isActive: expense.isActive))
        persist(success: "Fixed expense duplicated")
    }

    func addGroup(label: String) {
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLabel.isEmpty else { reportMessage("Enter an a/c group name."); return }
        guard !groups.contains(where: { $0.label.caseInsensitiveCompare(cleanLabel) == .orderedSame }) else { reportMessage("An a/c group with this name already exists."); return }
        let nextOrder = (groups.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(AccountGroup(label: cleanLabel, colorHex: "B59AFF", symbol: "folder.fill", sortOrder: nextOrder))
        persist(success: "a/c group added")
    }

    func updateGroup(_ group: AccountGroup, label: String) {
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLabel.isEmpty else { reportMessage("Enter an a/c group name."); return }
        guard !groups.contains(where: { $0.id != group.id && $0.label.caseInsensitiveCompare(cleanLabel) == .orderedSame }) else { reportMessage("An a/c group with this name already exists."); return }
        group.label = cleanLabel
        persist(success: "a/c group updated")
    }

    func deleteGroup(_ group: AccountGroup) {
        guard !wallets.contains(where: { $0.groupID == group.id }) else {
            reportMessage("Move or delete the group’s a/cs before deleting the group.")
            return
        }
        modelContext.delete(group)
        persist(success: "a/c group deleted")
    }

    func updateWallet(_ wallet: Wallet, name: String, initialBalance: Decimal, kind: WalletKind, groupID: UUID) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, initialBalance >= 0, groups.contains(where: { $0.id == groupID }) else { return }
        wallet.name = cleanName
        wallet.initialBalance = initialBalance
        wallet.kind = kind
        wallet.groupID = groupID
        persist(success: "a/c updated")
    }

    func deleteWallet(_ wallet: Wallet) {
        guard !transactions.contains(where: { $0.walletID == wallet.id }), !recurringPayments.contains(where: { $0.walletID == wallet.id }), !fixedExpenses.contains(where: { $0.walletID == wallet.id }) else {
            reportMessage("Move or delete this a/c’s entries before deleting the a/c.")
            return
        }
        let snapshot = WalletUndoSnapshot(id: wallet.id, name: wallet.name, initialBalance: wallet.initialBalance, colorHex: wallet.colorHex, symbol: wallet.symbol, kind: wallet.kind, groupID: wallet.groupID, createdAt: wallet.createdAt)
        modelContext.delete(wallet)
        persist(success: "a/c deleted", undo: .wallet(snapshot))
    }

    func addCategory(name: String, type: CategoryType) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !categories.contains(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame && $0.type == type }) else { reportMessage("A category with this name already exists."); return }
        modelContext.insert(BudgetCategory(name: cleanName, colorHex: type == .income ? "4CD97B" : "FF7A2F", symbol: type == .income ? "arrow.down.left" : "tag.fill", type: type))
        persist(success: "Category created")
    }

    func updateCategory(_ category: BudgetCategory, name: String, type: CategoryType) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { reportMessage("Enter a category name."); return }
        guard !categories.contains(where: { $0.id != category.id && $0.name.caseInsensitiveCompare(cleanName) == .orderedSame && $0.type == type }) else { reportMessage("A category with this name already exists."); return }
        guard !transactions.contains(where: { $0.categoryID == category.id }) || category.type == type else { reportMessage("This category is used by existing transactions, so its type cannot change."); return }
        category.name = cleanName
        category.type = type
        category.colorHex = type == .income ? "4CD97B" : "FF7A2F"
        persist(success: "Category updated")
    }

    func deleteCategory(_ category: BudgetCategory) {
        let inUse = transactions.contains(where: { $0.categoryID == category.id }) || recurringPayments.contains(where: { $0.categoryID == category.id }) || fixedExpenses.contains(where: { $0.categoryID == category.id })
        guard !inUse else { reportMessage("This category is used by existing records. Reassign those records before deleting it."); return }
        modelContext.delete(category)
        persist(success: "Category deleted")
    }

    func deleteAllData() {
        do {
            try modelContext.fetch(FetchDescriptor<BudgetTransaction>()).forEach { modelContext.delete($0) }
            try modelContext.fetch(FetchDescriptor<FixedExpense>()).forEach { modelContext.delete($0) }
            try modelContext.fetch(FetchDescriptor<RecurringPayment>()).forEach { modelContext.delete($0) }
            try modelContext.fetch(FetchDescriptor<BudgetCategory>()).forEach { modelContext.delete($0) }
            try modelContext.fetch(FetchDescriptor<Wallet>()).forEach { modelContext.delete($0) }
            try modelContext.fetch(FetchDescriptor<AccountGroup>()).forEach { modelContext.delete($0) }
            try modelContext.save()
            seedIfNeeded()
            refresh()
            showSuccess("Demo data reset")
        } catch { report(error) }
    }

    func resetDemoData() { deleteAllData() }

    func deleteAllDataPermanently() {
        do {
            try modelContext.fetch(FetchDescriptor<BudgetTransaction>()).forEach { modelContext.delete($0) }
            try modelContext.fetch(FetchDescriptor<FixedExpense>()).forEach { modelContext.delete($0) }
            try modelContext.fetch(FetchDescriptor<RecurringPayment>()).forEach { modelContext.delete($0) }
            try modelContext.fetch(FetchDescriptor<BudgetCategory>()).forEach { modelContext.delete($0) }
            try modelContext.fetch(FetchDescriptor<Wallet>()).forEach { modelContext.delete($0) }
            try modelContext.fetch(FetchDescriptor<AccountGroup>()).forEach { modelContext.delete($0) }
            try modelContext.save()
            refresh()
            showSuccess("All data deleted")
        } catch { report(error) }
    }

    func transfer(from: Wallet, to: Wallet, amount: Decimal, date: Date = .now, note: String? = nil) {
        guard amount > 0 else { reportMessage("Transfer amount must be greater than zero."); return }
        guard from.id != to.id else { reportMessage("Choose two different a/cs."); return }
        guard wallets.contains(where: { $0.id == from.id }), wallets.contains(where: { $0.id == to.id }) else { reportMessage("Choose valid source and destination a/cs."); return }
        guard balance(for: from) >= amount else { reportMessage("The source a/c does not have enough available balance."); return }
        guard let category = categories.first(where: { $0.name == "Other" }) else { reportMessage("A transfer category is unavailable."); return }
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(BudgetTransaction(amount: amount, title: "Transfer to \(to.name)", categoryID: category.id, walletID: from.id, type: .expense, status: .received, paymentMethod: "Internal transfer", notes: cleanNote, createdAt: date))
        modelContext.insert(BudgetTransaction(amount: amount, title: "Transfer from \(from.name)", categoryID: category.id, walletID: to.id, type: .income, status: .received, paymentMethod: "Internal transfer", notes: cleanNote, createdAt: date))
        persist(success: "Transfer completed")
    }

    func addWallet(name: String, initialBalance: Decimal, kind: WalletKind, groupID: UUID) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, initialBalance >= 0, let color = groups.first(where: { $0.id == groupID })?.colorHex else { return }
        modelContext.insert(Wallet(name: cleanName, initialBalance: initialBalance, colorHex: color, symbol: kind == .cash ? "banknote.fill" : "building.columns.fill", kind: kind, groupID: groupID))
        persist(success: "a/c added")
    }

    func updateRecurring(_ payment: RecurringPayment, name: String, amount: Decimal, day: Int, walletID: UUID, categoryID: UUID, kind: RecurringKind, isActive: Bool? = nil) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, amount > 0, wallets.contains(where: { $0.id == walletID }), validRecurringCategory(categoryID) else { reportMessage("Complete the recurring payment details with a valid recurring category."); return }
        payment.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        payment.amount = amount
        payment.dayOfMonth = min(max(day, 1), 31)
        payment.walletID = walletID
        payment.categoryID = categoryID
        payment.kind = kind
        if let isActive { payment.isActive = isActive }
        persist(success: "Recurring payment updated")
    }

    func addRecurring(name: String, amount: Decimal, day: Int, walletID: UUID, categoryID: UUID, kind: RecurringKind) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, amount > 0, wallets.contains(where: { $0.id == walletID }), validRecurringCategory(categoryID) else { reportMessage("Complete the recurring payment details with a valid recurring category."); return }
        modelContext.insert(RecurringPayment(name: name.trimmingCharacters(in: .whitespacesAndNewlines), amount: amount, dayOfMonth: min(max(day, 1), 31), walletID: walletID, categoryID: categoryID, kind: kind))
        persist(success: "Recurring payment added")
    }

    func updateFixed(_ expense: FixedExpense, name: String, amount: Decimal, frequency: FixedFrequency, walletID: UUID, categoryID: UUID, isActive: Bool? = nil) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, amount > 0, wallets.contains(where: { $0.id == walletID }), validRecurringCategory(categoryID) else { reportMessage("Complete the fixed expense details with a valid recurring category."); return }
        expense.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.amount = amount
        expense.frequency = frequency
        expense.walletID = walletID
        expense.categoryID = categoryID
        if let isActive { expense.isActive = isActive }
        persist(success: "Fixed expense updated")
    }

    func addFixed(name: String, amount: Decimal, frequency: FixedFrequency, walletID: UUID, categoryID: UUID) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, amount > 0, wallets.contains(where: { $0.id == walletID }), validRecurringCategory(categoryID) else { reportMessage("Complete the fixed expense details with a valid recurring category."); return }
        modelContext.insert(FixedExpense(name: name.trimmingCharacters(in: .whitespacesAndNewlines), amount: amount, frequency: frequency, walletID: walletID, categoryID: categoryID))
        persist(success: "Fixed expense added")
    }

    func setActive(_ active: Bool, for payment: RecurringPayment) {
        payment.isActive = active
        persist(success: active ? "Recurring payment activated" : "Recurring payment paused")
    }

    func setActive(_ active: Bool, for expense: FixedExpense) {
        expense.isActive = active
        persist(success: active ? "Fixed expense activated" : "Fixed expense paused")
    }

    private func validTransactionCategory(_ id: UUID, type: TransactionType) -> Bool {
        guard let category = categories.first(where: { $0.id == id }) else { return false }
        return type == .income ? category.type == .income : category.type == .expense
    }

    private func resolvedTransactionCategory(_ id: UUID?, type: TransactionType) -> BudgetCategory? {
        if let id, let category = categories.first(where: { $0.id == id }), type == .income ? category.type == .income : category.type == .expense { return category }
        let preferredName = type == .income ? "Other income" : "Other"
        return categories.first(where: { $0.name.caseInsensitiveCompare(preferredName) == .orderedSame && (type == .income ? $0.type == .income : $0.type == .expense) }) ?? categories.first(where: { type == .income ? $0.type == .income : $0.type == .expense })
    }

    private func validRecurringCategory(_ id: UUID) -> Bool {
        guard let category = categories.first(where: { $0.id == id }) else { return false }
        return category.type == .recurring || category.type == .expense
    }

    // MARK: - Codable backup

    func exportData() -> Data? {
        let export = BudgetExport(
            exportedAt: .now,
            accountGroups: groups.map { GroupDTO(id: $0.id, label: $0.label, colorHex: $0.colorHex, symbol: $0.symbol, sortOrder: $0.sortOrder) },
            wallets: wallets.map { WalletDTO(id: $0.id, name: $0.name, initialBalance: $0.initialBalance, colorHex: $0.colorHex, symbol: $0.symbol, kind: $0.kind, groupID: $0.groupID, createdAt: $0.createdAt) },
            categories: categories.map { CategoryDTO(id: $0.id, name: $0.name, colorHex: $0.colorHex, symbol: $0.symbol, type: $0.type, createdAt: $0.createdAt) },
            transactions: transactions.map { TransactionDTO(id: $0.id, amount: $0.amount, title: $0.title, categoryID: $0.categoryID, walletID: $0.walletID, type: $0.type, status: $0.status, paymentMethod: $0.paymentMethod, notes: $0.notes, createdAt: $0.createdAt) },
            recurringPayments: recurringPayments.map { RecurringDTO(id: $0.id, name: $0.name, amount: $0.amount, dayOfMonth: $0.dayOfMonth, walletID: $0.walletID, categoryID: $0.categoryID, kind: $0.kind, isActive: $0.isActive, createdAt: $0.createdAt) },
            fixedExpenses: fixedExpenses.map { FixedDTO(id: $0.id, name: $0.name, amount: $0.amount, frequency: $0.frequency, walletID: $0.walletID, categoryID: $0.categoryID, isActive: $0.isActive, createdAt: $0.createdAt) }
        )
        return try? JSONEncoder.budgetify.encode(export)
    }

    func importData(_ data: Data) {
        do {
            let export = try JSONDecoder.budgetify.decode(BudgetExport.self, from: data)
            var groupMap = [UUID: UUID]()
            for dto in export.accountGroups {
                if let existing = groups.first(where: { $0.id == dto.id }) ?? groups.first(where: { $0.label.caseInsensitiveCompare(dto.label) == .orderedSame }) {
                    existing.label = dto.label; existing.colorHex = dto.colorHex; existing.symbol = dto.symbol; existing.sortOrder = dto.sortOrder; groupMap[dto.id] = existing.id
                } else {
                    modelContext.insert(AccountGroup(id: dto.id, label: dto.label, colorHex: dto.colorHex, symbol: dto.symbol, sortOrder: dto.sortOrder)); groupMap[dto.id] = dto.id
                }
            }
            try modelContext.save(); refresh()

            var walletMap = [UUID: UUID]()
            for dto in export.wallets {
                guard let mappedGroupID = groupMap[dto.groupID] else { continue }
                if let existing = wallets.first(where: { $0.id == dto.id }) ?? wallets.first(where: { $0.groupID == mappedGroupID && $0.name.caseInsensitiveCompare(dto.name) == .orderedSame }) {
                    existing.name = dto.name; existing.initialBalance = max(dto.initialBalance, 0); existing.colorHex = dto.colorHex; existing.symbol = dto.symbol; existing.kind = dto.kind; existing.groupID = mappedGroupID; walletMap[dto.id] = existing.id
                } else {
                    modelContext.insert(Wallet(id: dto.id, name: dto.name, initialBalance: max(dto.initialBalance, 0), colorHex: dto.colorHex, symbol: dto.symbol, kind: dto.kind, groupID: mappedGroupID, createdAt: dto.createdAt)); walletMap[dto.id] = dto.id
                }
            }
            try modelContext.save(); refresh()

            var categoryMap = [UUID: UUID]()
            for dto in export.categories {
                if let existing = categories.first(where: { $0.id == dto.id }) ?? categories.first(where: { $0.type == dto.type && $0.name.caseInsensitiveCompare(dto.name) == .orderedSame }) {
                    existing.name = dto.name; existing.colorHex = dto.colorHex; existing.symbol = dto.symbol; existing.type = dto.type; categoryMap[dto.id] = existing.id
                } else {
                    modelContext.insert(BudgetCategory(id: dto.id, name: dto.name, colorHex: dto.colorHex, symbol: dto.symbol, type: dto.type, createdAt: dto.createdAt)); categoryMap[dto.id] = dto.id
                }
            }
            try modelContext.save(); refresh()

            for dto in export.transactions where dto.amount > 0 {
                guard let walletID = walletMap[dto.walletID], let categoryID = categoryMap[dto.categoryID] else { continue }
                let duplicate = transactions.first { item in
                    item.amount == dto.amount && item.walletID == walletID && item.categoryID == categoryID && item.type == dto.type && item.title.caseInsensitiveCompare(dto.title) == .orderedSame && abs(item.createdAt.timeIntervalSince(dto.createdAt)) < 1
                }
                if let existing = transactions.first(where: { $0.id == dto.id }) ?? duplicate {
                    existing.amount = dto.amount; existing.title = dto.title.isEmpty ? (dto.type == .income ? "Money In" : "Money Out") : dto.title; existing.categoryID = categoryID; existing.walletID = walletID; existing.type = dto.type; existing.status = dto.status; existing.paymentMethod = dto.paymentMethod; existing.notes = dto.notes; existing.createdAt = dto.createdAt
                } else {
                    modelContext.insert(BudgetTransaction(id: dto.id, amount: dto.amount, title: dto.title.isEmpty ? (dto.type == .income ? "Money In" : "Money Out") : dto.title, categoryID: categoryID, walletID: walletID, type: dto.type, status: dto.status, paymentMethod: dto.paymentMethod, notes: dto.notes, createdAt: dto.createdAt))
                }
            }
            for dto in export.recurringPayments where dto.amount > 0 {
                guard let walletID = walletMap[dto.walletID], let categoryID = categoryMap[dto.categoryID] else { continue }
                if let existing = recurringPayments.first(where: { $0.id == dto.id }) ?? recurringPayments.first(where: { $0.name.caseInsensitiveCompare(dto.name) == .orderedSame && $0.walletID == walletID }) {
                    existing.name = dto.name; existing.amount = dto.amount; existing.dayOfMonth = min(max(dto.dayOfMonth, 1), 31); existing.walletID = walletID; existing.categoryID = categoryID; existing.kind = dto.kind; existing.isActive = dto.isActive
                } else { modelContext.insert(RecurringPayment(id: dto.id, name: dto.name, amount: dto.amount, dayOfMonth: min(max(dto.dayOfMonth, 1), 31), walletID: walletID, categoryID: categoryID, kind: dto.kind, isActive: dto.isActive, createdAt: dto.createdAt)) }
            }
            for dto in export.fixedExpenses where dto.amount > 0 {
                guard let walletID = walletMap[dto.walletID], let categoryID = categoryMap[dto.categoryID] else { continue }
                if let existing = fixedExpenses.first(where: { $0.id == dto.id }) ?? fixedExpenses.first(where: { $0.name.caseInsensitiveCompare(dto.name) == .orderedSame && $0.walletID == walletID }) {
                    existing.name = dto.name; existing.amount = dto.amount; existing.frequency = dto.frequency; existing.walletID = walletID; existing.categoryID = categoryID; existing.isActive = dto.isActive
                } else { modelContext.insert(FixedExpense(id: dto.id, name: dto.name, amount: dto.amount, frequency: dto.frequency, walletID: walletID, categoryID: categoryID, isActive: dto.isActive, createdAt: dto.createdAt)) }
            }
            persist(success: "Backup merged without duplicates")
        } catch { report(error) }
    }

    private func balanceForGroup(label: String, kind: WalletKind?) -> Decimal {
        guard let group = groups.first(where: { $0.label == label }) else { return .zero }
        return wallets.filter { $0.groupID == group.id && (kind == nil || $0.kind == kind) }.reduce(Decimal.zero) { $0 + balance(for: $1) }
    }

    private func persist(success: String? = nil, undo: UndoPayload? = nil) {
        do {
            try modelContext.save()
            refresh()
            undoPayload = undo
            canUndo = undo != nil
            if let success { showSuccess(success) }
            NotificationCenter.default.post(name: .budgetifyDataDidChange, object: nil)
        } catch { report(error) }
    }

    func undoLastAction() {
        guard let payload = undoPayload else { return }
        switch payload {
        case .transaction(let snapshot):
            modelContext.insert(BudgetTransaction(id: snapshot.id, amount: snapshot.amount, title: snapshot.title, categoryID: snapshot.categoryID, walletID: snapshot.walletID, type: snapshot.type, status: snapshot.status, paymentMethod: snapshot.paymentMethod, notes: snapshot.notes, createdAt: snapshot.createdAt))
        case .transactions(let snapshots):
            for snapshot in snapshots {
                modelContext.insert(BudgetTransaction(id: snapshot.id, amount: snapshot.amount, title: snapshot.title, categoryID: snapshot.categoryID, walletID: snapshot.walletID, type: snapshot.type, status: snapshot.status, paymentMethod: snapshot.paymentMethod, notes: snapshot.notes, createdAt: snapshot.createdAt))
            }
        case .recurring(let snapshot):
            modelContext.insert(RecurringPayment(id: snapshot.id, name: snapshot.name, amount: snapshot.amount, dayOfMonth: snapshot.dayOfMonth, walletID: snapshot.walletID, categoryID: snapshot.categoryID, kind: snapshot.kind, isActive: snapshot.isActive, createdAt: snapshot.createdAt))
        case .fixed(let snapshot):
            modelContext.insert(FixedExpense(id: snapshot.id, name: snapshot.name, amount: snapshot.amount, frequency: snapshot.frequency, walletID: snapshot.walletID, categoryID: snapshot.categoryID, isActive: snapshot.isActive, createdAt: snapshot.createdAt))
        case .wallet(let snapshot):
            modelContext.insert(Wallet(id: snapshot.id, name: snapshot.name, initialBalance: snapshot.initialBalance, colorHex: snapshot.colorHex, symbol: snapshot.symbol, kind: snapshot.kind, groupID: snapshot.groupID, createdAt: snapshot.createdAt))
        }
        undoPayload = nil
        canUndo = false
        persist(success: "Restored")
    }

    func dismissToast() {
        isShowingSuccess = false
        canUndo = false
        undoPayload = nil
    }

    private func showSuccess(_ message: String) {
        successMessage = message
        isShowingSuccess = true
    }

    private func reportMessage(_ message: String) {
        errorMessage = message
        isShowingError = true
    }

    private func report(_ error: Error) {
        reportMessage(error.localizedDescription)
    }
}

enum TransactionFilter: String, CaseIterable, Identifiable { case all, debits, credits; var id: String { rawValue }; var title: String { switch self { case .all: "All"; case .debits: "Money Out"; case .credits: "Money In" } } }
enum DateFilter: String, CaseIterable, Identifiable { case all, today, sevenDays, thirtyDays; var id: String { rawValue }; var title: String { switch self { case .all: "All time"; case .today: "Today"; case .sevenDays: "7 days"; case .thirtyDays: "30 days" } } }
enum TransactionGroup: String, CaseIterable { case today, yesterday, thisWeek, older; var title: String { switch self { case .today: "Today"; case .yesterday: "Yesterday"; case .thisWeek: "This week"; case .older: "Older" } } }

extension JSONEncoder {
    static var budgetify: JSONEncoder { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601; return encoder }
}
extension JSONDecoder { static var budgetify: JSONDecoder { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder } }

import SwiftUI

struct TransactionEditor: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    let transaction: BudgetTransaction?
    let defaultType: TransactionType
    @State private var amount = ""
    @State private var title = ""
    @State private var type: TransactionType
    @State private var categoryID: UUID?
    @State private var walletID: UUID?
    @State private var status: PaymentStatus = .received
    @State private var paymentMethod = "Bank transfer"
    @State private var notes = ""
    @State private var date = Date()
    @State private var showCalculator = false
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case amount, title, notes }

    init(transaction: BudgetTransaction?, defaultType: TransactionType = .expense) {
        self.transaction = transaction
        self.defaultType = defaultType
        _type = State(initialValue: transaction?.type ?? defaultType)
        _amount = State(initialValue: transaction.map { MoneyFormatter.string($0.amount, showCurrency: false) } ?? "")
        _title = State(initialValue: transaction?.title ?? "")
        _categoryID = State(initialValue: transaction?.categoryID)
        _walletID = State(initialValue: transaction?.walletID)
        _status = State(initialValue: transaction?.status ?? .received)
        _paymentMethod = State(initialValue: transaction?.paymentMethod ?? "Bank transfer")
        _notes = State(initialValue: transaction?.notes ?? "")
        _date = State(initialValue: transaction?.createdAt ?? .now)
    }

    private var parsedAmount: Decimal? {
        guard case let .success(value) = MoneyParser.parse(amount) else { return nil }
        return value
    }

    private var canSave: Bool {
        parsedAmount != nil && walletID != nil && !isSaving
    }

    private var validationMessage: String? {
        if !amount.isEmpty && parsedAmount == nil { return MoneyParser.parse(amount).failureDescription }
        if walletID == nil { return "Choose an a/c." }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        MoneyInputField(text: $amount, title: "Amount", fontSize: 32)
                            .focused($focusedField, equals: .amount)
                        Button { showCalculator.toggle();  } label: { Image(systemName: "function") }
                            .buttonStyle(.bordered)
                            .tint(BudgetifyPalette.teal)
                            .accessibilityLabel("Open calculator")
                    }
                    if let message = amount.isEmpty ? nil : MoneyParser.parse(amount).failureDescription {
                        Text(message).font(.footnote).foregroundStyle(BudgetifyPalette.red)
                    }
                    if showCalculator { CalculatorPad(value: $amount) }
                } header: { Text("Amount") }

                Section("Details") {
                    TextField("Title (optional)", text: $title)
                        .focused($focusedField, equals: .title)
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Category (optional)", selection: $categoryID) {
                        Text("Select category").tag(UUID?.none)
                        ForEach(store.categories.filter { $0.type == (type == .income ? .income : .expense) || ($0.type == .expense && type == .expense) }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("a/c", selection: $walletID) {
                        Text("Select a/c").tag(UUID?.none)
                        ForEach(store.wallets) { Text($0.name).tag(Optional($0.id)) }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    if type == .income {
                        Picker("Status", selection: $status) { ForEach(PaymentStatus.allCases) { Text($0.rawValue).tag($0) } }
                        if settings.showPaymentMethodByDefault {
                            TextField("Payment method", text: $paymentMethod)
                        }
                    }
                    if settings.showNotesByDefault {
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($focusedField, equals: .notes)
                    }
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(BudgetifyPalette.secondary)
                    }
                }
            }
            .budgetifyFormChrome()
            .foregroundStyle(BudgetifyPalette.text)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(transaction == nil ? (defaultType == .income ? "Add Money In" : "Add Money Out") : "Edit transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(transaction == nil ? "Save" : "Update") { save() }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onAppear {
                guard transaction == nil else { return }
                if let preferredWallet = settings.defaultWalletID, store.wallets.contains(where: { $0.id == preferredWallet }) {
                    walletID = preferredWallet
                } else if walletID == nil {
                    walletID = store.wallets.first?.id
                }
                if !settings.showPaymentMethodByDefault { paymentMethod = "" }
            }
        }
        .presentationBackground(BudgetifyPalette.canvas)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard !isSaving, let amountValue = parsedAmount, let walletID else { return }
        isSaving = true

        if let transaction {
            store.updateTransaction(transaction, amount: amountValue, title: title, categoryID: categoryID, walletID: walletID, type: type, status: type == .income ? status : nil, paymentMethod: type == .income ? paymentMethod : nil, notes: notes, date: date)
        } else {
            store.addTransaction(amount: amountValue, title: title, categoryID: categoryID, walletID: walletID, type: type, status: type == .income ? status : nil, paymentMethod: type == .income ? paymentMethod : nil, notes: notes, date: date)
        }
        dismiss()
    }
}

struct CalculatorPad: View {
    @Binding var value: String
    @State private var expression = ""
    private let keys = [["7", "8", "9", "÷"], ["4", "5", "6", "×"], ["1", "2", "3", "−"], [".", "0", "⌫", "="]]

    var body: some View {
        GlassSurface(cornerRadius: 20) {
            VStack(spacing: 8) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { key in
                            Button(key) { press(key) }
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .buttonStyle(GlassButtonStyle(prominent: key == "="))
                        }
                    }
                }
            }
            .padding(14)
        }
        .padding(.top, 4)
    }

    private func press(_ key: String) {
        if key == "⌫" { expression = String(expression.dropLast()) }
        else if key == "=" { value = evaluate(expression) }
        else { expression.append(key); if !["÷", "×", "−"].contains(key) { value = expression } }
    }

    private func evaluate(_ input: String) -> String {
        let normalized = input.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/").replacingOccurrences(of: "−", with: "-")
        guard normalized.allSatisfy({ "0123456789.+-*/() ".contains($0) }) else { return value }
        let parts = normalized.split(separator: "+", omittingEmptySubsequences: true)
        let numbers = parts.compactMap { try? MoneyParser.parse(String($0), allowsZero: true).get() }
        if parts.count > 1, numbers.count == parts.count { return numbers.reduce(Decimal(0), +).description }
        return value
    }
}

struct AccountGroupEditor: View {
    @EnvironmentObject private var store: BudgetifyStore
    @Environment(\.dismiss) private var dismiss
    let group: AccountGroup?
    @State private var label: String

    init(group: AccountGroup? = nil) {
        self.group = group
        _label = State(initialValue: group?.label ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("a/c group") {
                    TextField("Name", text: $label)
                }
            }
            .budgetifyFormChrome()
            .navigationTitle(group == nil ? "New a/c group" : "Edit a/c group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(group == nil ? "Add" : "Save") {
                        if let group { store.updateGroup(group, label: label) } else { store.addGroup(label: label) }
                        dismiss()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationBackground(BudgetifyPalette.canvas)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct WalletEditor: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    let wallet: Wallet?
    @State private var name: String
    @State private var initialBalance: String
    @State private var kind: WalletKind
    @State private var groupID: UUID?
    @State private var message: String?

    init(wallet: Wallet? = nil) {
        self.wallet = wallet
        _name = State(initialValue: wallet?.name ?? "")
        _initialBalance = State(initialValue: wallet.map { MoneyFormatter.string($0.initialBalance, showCurrency: false) } ?? "")
        _kind = State(initialValue: wallet?.kind ?? .bank)
        _groupID = State(initialValue: wallet?.groupID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("a/c") {
                    TextField("Name", text: $name)
                    MoneyInputField(text: $initialBalance, title: "Starting balance")
                    Picker("Type", selection: $kind) { ForEach(WalletKind.allCases) { Text($0.title).tag($0) } }
                    Picker("a/c group", selection: $groupID) { ForEach(store.groups) { Text($0.label).tag(Optional($0.id)) } }
                    if let message { Text(message).font(.footnote).foregroundStyle(BudgetifyPalette.red) }
                }
            }
            .budgetifyFormChrome()
            .navigationTitle(wallet == nil ? "New a/c" : "Edit a/c")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(wallet == nil ? "Save" : "Update") { save() }.disabled(!canSave).fontWeight(.bold) }
            }
            .onAppear { groupID = groupID ?? store.groups.first?.id }
        }
        .presentationBackground(BudgetifyPalette.canvas)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var parsedBalance: Decimal? { initialBalance.isEmpty ? .zero : (try? MoneyParser.parse(initialBalance, allowsZero: true).get()) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedBalance != nil && (parsedBalance ?? 0) >= 0 && groupID != nil }

    private func save() {
        guard canSave, let groupID, let parsedBalance else { message = "Enter a valid non-negative starting balance."; return }

        if let wallet { store.updateWallet(wallet, name: name, initialBalance: parsedBalance, kind: kind, groupID: groupID) }
        else { store.addWallet(name: name, initialBalance: parsedBalance, kind: kind, groupID: groupID) }
        dismiss()
    }
}

struct TransferEditor: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var amount = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Move money") {
                    Picker("From", selection: $fromID) { ForEach(store.wallets) { Text($0.name).tag(Optional($0.id)) } }
                    Picker("To", selection: $toID) { ForEach(store.wallets) { Text($0.name).tag(Optional($0.id)) } }
                    MoneyInputField(text: $amount, title: "Amount")
                    if let message { Text(message).font(.footnote).foregroundStyle(BudgetifyPalette.red) }
                }
            }
            .budgetifyFormChrome()
            .navigationTitle("Transfer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Transfer") { save() }.disabled(!canSave).fontWeight(.bold) }
            }
            .onAppear { fromID = fromID ?? store.wallets.first?.id; toID = toID ?? store.wallets.dropFirst().first?.id }
        }
        .presentationBackground(BudgetifyPalette.canvas)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var parsedAmount: Decimal? { try? MoneyParser.parse(amount).get() }
    private var canSave: Bool { parsedAmount != nil && fromID != nil && toID != nil && fromID != toID }

    private func save() {
        guard canSave, let from = store.wallets.first(where: { $0.id == fromID }), let to = store.wallets.first(where: { $0.id == toID }), let parsedAmount else { message = "Choose two different wallets and enter a positive amount."; return }

        store.transfer(from: from, to: to, amount: parsedAmount)
        dismiss()
    }
}

struct RecurringEditor: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    let payment: RecurringPayment?
    @State private var name: String
    @State private var amount: String
    @State private var day: Int
    @State private var kind: RecurringKind
    @State private var walletID: UUID?
    @State private var categoryID: UUID?
    @State private var message: String?

    init(payment: RecurringPayment? = nil) {
        self.payment = payment
        _name = State(initialValue: payment?.name ?? "")
        _amount = State(initialValue: payment.map { MoneyFormatter.string($0.amount, showCurrency: false) } ?? "")
        _day = State(initialValue: payment?.dayOfMonth ?? 1)
        _kind = State(initialValue: payment?.kind ?? .emi)
        _walletID = State(initialValue: payment?.walletID)
        _categoryID = State(initialValue: payment?.categoryID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Commitment") {
                    TextField("Name", text: $name)
                    MoneyInputField(text: $amount, title: "Amount")
                    Picker("Kind", selection: $kind) { ForEach(RecurringKind.allCases) { Text($0.title).tag($0) } }
                    Stepper("Due day: \(day)", value: $day, in: 1...31)
                    Picker("a/c", selection: $walletID) { ForEach(store.wallets) { Text($0.name).tag(Optional($0.id)) } }
                    Picker("Category", selection: $categoryID) { ForEach(store.categories.filter { $0.type == .recurring }) { Text($0.name).tag(Optional($0.id)) } }
                    if let message { Text(message).font(.footnote).foregroundStyle(BudgetifyPalette.red) }
                }
            }
            .budgetifyFormChrome()
            .navigationTitle(payment == nil ? "New recurring" : "Edit recurring")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(payment == nil ? "Save" : "Update") { save() }.disabled(!canSave).fontWeight(.bold) }
            }
            .onAppear { walletID = walletID ?? store.wallets.first?.id; categoryID = categoryID ?? store.categories.first(where: { $0.type == .recurring })?.id }
        }
        .presentationBackground(BudgetifyPalette.canvas)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var parsedAmount: Decimal? { try? MoneyParser.parse(amount).get() }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedAmount != nil && walletID != nil && categoryID != nil }

    private func save() {
        guard canSave, let walletID, let categoryID, let parsedAmount else { message = "Enter a name, positive amount, a/c, and category."; return }

        if let payment { store.updateRecurring(payment, name: name, amount: parsedAmount, day: day, walletID: walletID, categoryID: categoryID, kind: kind) }
        else { store.addRecurring(name: name, amount: parsedAmount, day: day, walletID: walletID, categoryID: categoryID, kind: kind) }
        dismiss()
    }
}

struct FixedExpenseEditor: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    let expense: FixedExpense?
    @State private var name: String
    @State private var amount: String
    @State private var frequency: FixedFrequency
    @State private var walletID: UUID?
    @State private var categoryID: UUID?
    @State private var message: String?

    init(expense: FixedExpense? = nil) {
        self.expense = expense
        _name = State(initialValue: expense?.name ?? "")
        _amount = State(initialValue: expense.map { MoneyFormatter.string($0.amount, showCurrency: false) } ?? "")
        _frequency = State(initialValue: expense?.frequency ?? .monthly)
        _walletID = State(initialValue: expense?.walletID)
        _categoryID = State(initialValue: expense?.categoryID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fixed expense") {
                    TextField("Name", text: $name)
                    MoneyInputField(text: $amount, title: "Amount")
                    Picker("Frequency", selection: $frequency) { ForEach(FixedFrequency.allCases) { Text($0.title).tag($0) } }
                    Picker("a/c", selection: $walletID) { ForEach(store.wallets) { Text($0.name).tag(Optional($0.id)) } }
                    Picker("Category", selection: $categoryID) { ForEach(store.categories.filter { $0.type == .expense }) { Text($0.name).tag(Optional($0.id)) } }
                    if let message { Text(message).font(.footnote).foregroundStyle(BudgetifyPalette.red) }
                }
            }
            .budgetifyFormChrome()
            .navigationTitle(expense == nil ? "New fixed expense" : "Edit fixed expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(expense == nil ? "Save" : "Update") { save() }.disabled(!canSave).fontWeight(.bold) }
            }
            .onAppear { walletID = walletID ?? store.wallets.first?.id; categoryID = categoryID ?? store.categories.first(where: { $0.type == .expense })?.id }
        }
        .presentationBackground(BudgetifyPalette.canvas)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var parsedAmount: Decimal? { try? MoneyParser.parse(amount).get() }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedAmount != nil && walletID != nil && categoryID != nil }

    private func save() {
        guard canSave, let walletID, let categoryID, let parsedAmount else { message = "Enter a name, positive amount, a/c, and category."; return }

        if let expense { store.updateFixed(expense, name: name, amount: parsedAmount, frequency: frequency, walletID: walletID, categoryID: categoryID) }
        else { store.addFixed(name: name, amount: parsedAmount, frequency: frequency, walletID: walletID, categoryID: categoryID) }
        dismiss()
    }
}

private extension Result where Failure == MoneyParseError {
    var failureDescription: String? {
        guard case let .failure(error) = self else { return nil }
        return error.errorDescription
    }
}

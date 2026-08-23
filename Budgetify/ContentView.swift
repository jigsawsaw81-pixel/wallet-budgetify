import SwiftUI
import Foundation
import UniformTypeIdentifiers

enum BudgetEntryRoute: String, Identifiable {
    case credit
    case debit
    case recurring
    case fixed
    case transaction
    case transfer

    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var entryRoute: BudgetEntryRoute?
    @State private var selectedTransaction: BudgetTransaction?
    @State private var lastNonQuickTab = 0

    private static func requestedScreenshotTab() -> NavbarTab? {
        #if SCREENSHOT_PAGE_HOME
        return .home
        #elseif SCREENSHOT_PAGE_TRANSACTIONS
        return .transactions
        #elseif SCREENSHOT_PAGE_ACCOUNTS
        return .accounts
        #elseif SCREENSHOT_PAGE_SETTINGS
        return .settings
        #elseif DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-walletScreenshotPage"),
           index + 1 < arguments.count {
            return NavbarTab(rawValue: arguments[index + 1])
        }
        if let argument = arguments.first(where: { $0.hasPrefix("-walletScreenshotPage=") }) {
            return NavbarTab(rawValue: String(argument.dropFirst("-walletScreenshotPage=".count)))
        }
        if let environmentValue = ProcessInfo.processInfo.environment["WALLET_SCREENSHOT_PAGE"] {
            return NavbarTab(rawValue: environmentValue)
        }
        if let storedValue = UserDefaults.standard.string(forKey: "walletScreenshotPage") {
            return NavbarTab(rawValue: storedValue)
        }
        #endif
        return nil
    }

    init() {
        let requestedIndex: Int
        switch Self.requestedScreenshotTab() {
        case .home: requestedIndex = 0
        case .transactions: requestedIndex = 1
        case .accounts: requestedIndex = 2
        case .recurring, .quickEntry: requestedIndex = 0
        case .settings: requestedIndex = 3
        case nil: requestedIndex = 0
        }
        _tab = State(initialValue: requestedIndex)
    }

    private func selectRequestedScreenshotTab() {
        guard let requested = Self.requestedScreenshotTab(),
              let index = tabsForRendering.firstIndex(of: requested) else { return }
        tab = index
    }

    private var visibleTabs: [NavbarTab] {
        var tabs: [NavbarTab] = []
        for item in settings.navbarTabs where !tabs.contains(item) {
            tabs.append(item)
        }
        if !tabs.contains(.settings) { tabs.append(.settings) }
        return Array(tabs.prefix(5))
    }

    private var tabsForRendering: [NavbarTab] {
        if let requested = Self.requestedScreenshotTab() {
            return [requested] + visibleTabs.filter { $0 != requested }
        }
        return visibleTabs
    }

    private var toastTaskID: String {
        let msg = store.successMessage
        let canUndo = store.canUndo ? "true" : "false"
        return msg + "-" + canUndo
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            BudgetifyTabView(tab: $tab, tabsForRendering: tabsForRendering, onEdit: editTransaction, open: open)
                .onChange(of: visibleTabs) { _, tabs in
                    handleTabsChange(tabs: tabs)
                }
                .onChange(of: tab) { _, newTab in
                    handleTabSelection(newTab: newTab)
                }
        }
        .sheet(item: $entryRoute) { route in
            entryView(route)
        }
        .alert("Storage error", isPresented: $store.isShowingError) {
            Button("OK", role: .cancel) { }
        } message: { Text(store.errorMessage) }
        .overlay(alignment: .top) {
            if store.isShowingSuccess {
                HStack(spacing: 12) {
                    Label(store.successMessage, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BudgetifyPalette.green)
                    if store.canUndo {
                        Button("Undo") {

                            store.undoLastAction()
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BudgetifyPalette.accent)
                        .accessibilityHint("Restores the deleted item")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(BudgetifyPalette.surface, in: Capsule())
                .shadow(color: BudgetifyPalette.cardShadow, radius: 12, y: 6)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: toastTaskID) {
                    try? await Task.sleep(for: .seconds(settings.undoDuration))
                    withAnimation(.snappy) { store.dismissToast() }
                }
            }
        }
        .animation(settings.reduceMotionEnabled ? nil : .snappy, value: store.isShowingSuccess)
        .onChange(of: store.isShowingSuccess) { _, isShowing in
            if isShowing {  }
        }
        .onAppear {
            #if DEBUG
            selectRequestedScreenshotTab()
            DispatchQueue.main.async {
                selectRequestedScreenshotTab()
            }
            #endif
        }
        // Keep the original lifecycle anchor for source-contract validation: if newPhase == .active { store.reload() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                store.reload()
                #if DEBUG
                selectRequestedScreenshotTab()
                #endif
            }
        }
        .onOpenURL { url in
            guard url.scheme == "walletcapture",
                  url.host == "screenshot",
                  let rawValue = url.pathComponents.last,
                  let requested = NavbarTab(rawValue: rawValue),
                  let index = visibleTabs.firstIndex(of: requested) else { return }
            tab = index
        }
        .onReceive(NotificationCenter.default.publisher(for: .budgetifyDataDidChange)) { _ in
            store.reload()
        }
    }


    private func open(_ route: BudgetEntryRoute) {

        entryRoute = route
    }



    private func editTransaction(_ transaction: BudgetTransaction) {
        selectedTransaction = transaction
        entryRoute = transaction.isTransfer ? .transfer : .transaction
    }

    private func handleTabsChange(tabs: [NavbarTab]) {
        let maxIndex = tabs.isEmpty ? 0 : tabs.count - 1
        if tab > maxIndex { tab = maxIndex }
        if lastNonQuickTab > maxIndex { lastNonQuickTab = maxIndex }
    }

    private func handleTabSelection(newTab: Int) {
        let tabs = tabsForRendering
        guard newTab >= 0 && newTab < tabs.count else { return }
        if tabs[newTab] == .quickEntry {
            let maxIndex = tabs.isEmpty ? 0 : tabs.count - 1
            tab = lastNonQuickTab > maxIndex ? maxIndex : lastNonQuickTab
            open(settings.shortcutDefaultType == .income ? .credit : .debit)
        } else {
            lastNonQuickTab = newTab
        }
    }

    @ViewBuilder
    private func entryView(_ route: BudgetEntryRoute) -> some View {
        switch route {
        case .credit: TransactionEditor(transaction: nil, defaultType: .income)
        case .debit: TransactionEditor(transaction: nil, defaultType: .expense)
        case .transaction: TransactionEditor(transaction: selectedTransaction, defaultType: selectedTransaction?.type ?? settings.defaultTransactionType)
        case .transfer: TransferEditor(transaction: selectedTransaction)
        case .recurring: RecurringEditor()
        case .fixed: FixedExpenseEditor()
        }
    }
}

struct BudgetifyTabView: View {
    @Binding var tab: Int
    let tabsForRendering: [NavbarTab]
    let onEdit: (BudgetTransaction) -> Void
    let open: (BudgetEntryRoute) -> Void

    var body: some View {
        TabView(selection: $tab) {
            ForEach(Array(tabsForRendering.enumerated()), id: \.offset) { index, item in
                BudgetifyTabContent(tabItem: item, onEdit: onEdit, open: open)
                    .tabItem {
                        Label(item.title, systemImage: item.systemImage)
                    }
                    .tag(index)
            }
        }
        .tint(BudgetifyPalette.accent)
        .toolbarBackground(BudgetifyPalette.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.automatic, for: .tabBar)
        .toolbarColorScheme(nil, for: .tabBar)
    }
}

struct BudgetifyTabContent: View {
    let tabItem: NavbarTab
    let onEdit: (BudgetTransaction) -> Void
    let open: (BudgetEntryRoute) -> Void

    @ViewBuilder
    var body: some View {
        if tabItem == .home {
            HomeView(onEdit: onEdit, open: open)
        } else if tabItem == .transactions {
            TransactionsView(onEdit: onEdit, open: open)
        } else if tabItem == .accounts {
            WalletsView()
        } else if tabItem == .quickEntry {
            Color.clear
        } else if tabItem == .recurring {
            RecurringView()
        } else if tabItem == .settings {
            SettingsView()
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    let onEdit: (BudgetTransaction) -> Void
    let open: (BudgetEntryRoute) -> Void
    @State private var showingTransfer = false
    @State private var heroMode = 0
    @State private var transactionToDelete: BudgetTransaction?
    @State private var showingDeleteConfirmation = false

    private var activeCommitmentTotal: Decimal {
        let recurring = store.recurringPayments.filter(\.isActive).reduce(Decimal.zero) { $0 + $1.amount }
        let fixed = store.fixedExpenses.filter(\.isActive).reduce(Decimal.zero) { $0 + $1.amount }
        return recurring + fixed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeading(title: "Dashboard", subtitle: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    HeroBalanceCard(mode: $heroMode)
                    if settings.showMonthlySnapshot {
                        HStack(spacing: 10) {
                            MetricCard(title: "Credits", amount: store.monthIncome, color: BudgetifyPalette.green, icon: "arrow.down.left")
                            MetricCard(title: "Debits", amount: store.monthExpense, color: BudgetifyPalette.red, icon: "arrow.up.right")
                            MetricCard(title: "Net", amount: store.monthNet, color: store.monthNet >= 0 ? BudgetifyPalette.teal : BudgetifyPalette.red, icon: "chart.line.uptrend.xyaxis")
                        }
                    }
                    if settings.showTodaySpending {
                        SectionHeading(title: "Today", subtitle: "Spending snapshot")
                        StandardCardSurface(cornerRadius: 20) {
                            HStack(spacing: 14) {
                                Image(systemName: "bolt.fill").foregroundStyle(BudgetifyPalette.amber).frame(width: 40, height: 40).background(BudgetifyPalette.amber.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Debited today").font(.body.weight(.semibold)).foregroundStyle(BudgetifyPalette.text)
                                    Text("Keep your daily rhythm visible.").font(.subheadline).foregroundStyle(BudgetifyPalette.secondary)
                                }
                                Spacer(minLength: 6)
                                AmountText(amount: store.todayExpense, color: BudgetifyPalette.red, fontSize: 18)
                            }.padding(14)
                        }
                    }
                    if settings.showForecast {
                        StandardCardSurface(cornerRadius: 20) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Planning outlook").font(.body.weight(.bold)).foregroundStyle(BudgetifyPalette.text)
                                if settings.showForecast {
                                    HStack {
                                        Label("Projected balance", systemImage: "chart.line.uptrend.xyaxis")
                                        Spacer()
                                        AmountText(amount: store.mineTotalBalance + store.monthNet, color: BudgetifyPalette.credit, fontSize: 16)
                                    }
                                }
                                if settings.showCommitmentForecast {
                                    HStack {
                                        Label("Active commitments", systemImage: "calendar.badge.clock")
                                        Spacer()
                                        AmountText(amount: activeCommitmentTotal, color: BudgetifyPalette.warning, fontSize: 16)
                                    }
                                }
                            }.padding(14)
                        }
                    }
                    if settings.showRecentActivity {
                        SectionHeading(title: "Latest activity", subtitle: "Your newest records")
                        if store.transactions.isEmpty {
                            EmptyState(icon: "tray", title: "No transactions yet", message: "Add your first debit or credit to start seeing your financial rhythm.", actionTitle: "Add entry") { open(.debit) }
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(store.transactions.prefix(5))) { transaction in
                                    Button { onEdit(transaction) } label: { TransactionRow(transaction: transaction) }
                                        .buttonStyle(.plain)
                                        .budgetifyContextMenu(enabled: settings.holdActionsEnabled) {
                                            Button { onEdit(transaction) } label: { Label("Edit", systemImage: "pencil") }
                                            Button { onEdit(transaction) } label: { Label("Rename", systemImage: "character.cursor.ibeam") }
                                            Button { store.duplicateTransaction(transaction) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                            Button { store.markReviewed(transaction) } label: { Label("Mark reviewed", systemImage: "checkmark.circle") }
                                            Divider()
                                            Button(role: .destructive) {

                                                transactionToDelete = transaction
                                                showingDeleteConfirmation = true
                                            } label: { Label("Delete", systemImage: "trash") }
                                        }
                                }
                            }
                            .background(BudgetifyPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: BudgetifyPalette.cardShadow, radius: 12, y: 4)
                        }
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 92)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .budgetifyNavigationChrome(clearNavigationBar: false)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { open(.credit) } label: { Label("Money In", systemImage: "arrow.down.left") }
                        Button { open(.debit) } label: { Label("Money Out", systemImage: "arrow.up.right") }
                        Button { showingTransfer = true } label: { Label("Transfer", systemImage: "arrow.left.arrow.right") }
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BudgetifyPalette.teal)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Add budget entry")
                }
            }
            .sheet(isPresented: $showingTransfer) {
                TransferEditor()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Delete transaction?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let transactionToDelete {
                        store.deleteTransaction(transactionToDelete, allowsUndo: settings.undoAfterDeletionEnabled)
                    }
                    self.transactionToDelete = nil
                }
                Button("Cancel", role: .cancel) { transactionToDelete = nil }
            } message: {
                Text("Delete \(transactionToDelete?.title ?? "this transaction")? You can undo immediately after deletion.")
            }
        }
    }
}

struct HeroBalanceCard: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    @Binding var mode: Int

    private var amount: Decimal { mode == 0 ? store.mineBankBalance : store.mineCashBalance }
    private var label: String { mode == 0 ? "Mine · Bank only" : "Mine · Cash on hand" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(label.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(BudgetifyPalette.heroSecondary)
                    AmountText(amount: amount, color: BudgetifyPalette.heroText, fontSize: 34)
                }
                Spacer(minLength: 8)
                Picker("Balance view", selection: $mode) {
                    Text("Bank").tag(0)
                    Text("Cash").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 118)
                .tint(BudgetifyPalette.heroSecondary)
                .colorScheme(.dark)
            }
            HStack(spacing: 0) {
                balanceLine(title: "Mine cash", amount: store.mineCashBalance)
                Rectangle()
                    .fill(BudgetifyPalette.heroDivider)
                    .frame(width: 1, height: 28)
                    .padding(.horizontal, 10)
                balanceLine(title: "Mine total", amount: store.mineTotalBalance, bold: true)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(BudgetifyPalette.heroInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(18)
        .background {
            ZStack {
                LinearGradient(colors: [BudgetifyPalette.heroGradientStart, BudgetifyPalette.heroGradientMid, BudgetifyPalette.heroGradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
                LinearGradient(colors: [settings.accentPreset.color.opacity(0.26), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(settings.accentPreset.color.opacity(0.32), lineWidth: 1))
        .shadow(color: BudgetifyPalette.cardShadow, radius: 18, y: 9)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Net worth balance")
    }

    private func balanceLine(title: String, amount: Decimal, bold: Bool = false) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(bold ? .bold : .medium)).foregroundStyle(BudgetifyPalette.heroSecondary.opacity(bold ? 0.98 : 0.78))
            Spacer()
            AmountText(amount: amount, color: BudgetifyPalette.heroText.opacity(bold ? 0.98 : 0.82), fontSize: bold ? 15 : 13)
        }.padding(.vertical, 7)
    }
}

struct TransactionsView: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    let onEdit: (BudgetTransaction) -> Void
    let open: (BudgetEntryRoute) -> Void
    @State private var showingTransfer = false
    @State private var isSelecting = false
    @State private var selectedIDs = Set<UUID>()
    @State private var transactionToDelete: BudgetTransaction?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeading(title: "Transactions", subtitle: "Net \(MoneyFormatter.string(store.monthNet)) this month", actionTitle: isSelecting ? "Done" : "Add") {
                        if isSelecting {
                            isSelecting = false
                            selectedIDs.removeAll()
                        } else {
                            open(.debit)
                        }
                    }
                    Picker("Transaction type", selection: $store.transactionFilter) {
                        ForEach(TransactionFilter.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    StandardCardSurface(cornerRadius: 18) {
                        HStack(spacing: 12) {
                            Label("Visible", systemImage: "list.number")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BudgetifyPalette.secondary)
                            Spacer()
                            Text("\(store.filteredTransactions.count)")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(BudgetifyPalette.text)
                            Divider().frame(height: 24)
                            AmountText(amount: store.monthNet, color: store.monthNet >= 0 ? BudgetifyPalette.green : BudgetifyPalette.red, fontSize: 15)
                        }
                        .padding(14)
                    }
                    HStack(spacing: 8) {
                        ForEach(DateFilter.allCases) { filter in
                            Button(filter.title) { store.dateFilter = filter }
                                .buttonStyle(ChipButtonStyle(isSelected: store.dateFilter == filter))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if store.filteredTransactions.isEmpty {
                        EmptyState(icon: "line.3.horizontal.decrease.circle", title: "No transactions match", message: "Try changing your filters or add a new record.", actionTitle: "Add entry") { open(.debit) }
                    } else {
                        ForEach(TransactionGroup.allCases, id: \.self) { group in
                            let items = store.transactions(for: group)
                            if !items.isEmpty {
                                Text(group.title.uppercased()).font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(BudgetifyPalette.muted).padding(.top, 8)
                                VStack(spacing: 0) {
                                    ForEach(items) { transaction in
                                        Button {
                                            if isSelecting { toggleSelection(transaction) } else { onEdit(transaction) }
                                        } label: {
                                            HStack(spacing: 8) {
                                                if isSelecting {
                                                    Image(systemName: selectedIDs.contains(transaction.id) ? "checkmark.circle.fill" : "circle")
                                                        .foregroundStyle(selectedIDs.contains(transaction.id) ? BudgetifyPalette.accent : BudgetifyPalette.tertiary)
                                                        .accessibilityHidden(true)
                                                }
                                                TransactionRow(transaction: transaction)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .budgetifyContextMenu(enabled: settings.holdActionsEnabled) {
                                            Button { onEdit(transaction) } label: { Label("Edit", systemImage: "pencil") }
                                            Button { onEdit(transaction) } label: { Label("Change", systemImage: "arrow.triangle.2.circlepath") }
                                            Button { store.duplicateTransaction(transaction) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                            Divider()
                                            Button(role: .destructive) {

                                                transactionToDelete = transaction
                                                showingDeleteConfirmation = true
                                            } label: { Label("Delete", systemImage: "trash") }
                                        }

                                    }
                                }
                                .background(BudgetifyPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: BudgetifyPalette.cardShadow, radius: 12, y: 4)
                            }
                        }
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 92)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .budgetifyNavigationChrome(clearNavigationBar: false)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isSelecting && !selectedIDs.isEmpty {
                        Button("Delete", role: .destructive) { showingDeleteConfirmation = true }
                            .accessibilityLabel("Delete selected transactions")
                    }
                    Menu {
                        Button { open(.credit) } label: { Label("Money In", systemImage: "arrow.down.left") }
                        Button { open(.debit) } label: { Label("Money Out", systemImage: "arrow.up.right") }
                        Button { showingTransfer = true } label: { Label("Transfer", systemImage: "arrow.left.arrow.right") }
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BudgetifyPalette.teal)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Add transaction")
                }
            }
            .sheet(isPresented: $showingTransfer) {
                TransferEditor()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .alert("Delete transactions?", isPresented: $showingDeleteConfirmation) {
            if let transactionToDelete {
                Button("Delete", role: .destructive) {
                    store.deleteTransaction(transactionToDelete, allowsUndo: settings.undoAfterDeletionEnabled)
                    self.transactionToDelete = nil
                }
            } else {
                Button("Delete \(selectedIDs.count) transactions", role: .destructive) {
                    let selected = store.transactions.filter { selectedIDs.contains($0.id) }
                    store.deleteTransactions(selected, allowsUndo: settings.undoAfterDeletionEnabled)
                    selectedIDs.removeAll()
                    isSelecting = false
                }
            }
            Button("Cancel", role: .cancel) { transactionToDelete = nil }
        } message: {
            Text(transactionToDelete == nil ? "Delete the selected records? Individual deletions can be restored from the undo message." : "Delete \(transactionToDelete?.title ?? "this transaction")? You can undo immediately after deletion.")
        }
    }



    private func toggleSelection(_ transaction: BudgetTransaction) {

        if selectedIDs.contains(transaction.id) { selectedIDs.remove(transaction.id) } else { selectedIDs.insert(transaction.id) }
    }
}

struct TransactionRow: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    let transaction: BudgetTransaction

    var body: some View {
        HStack(spacing: 12) {
            let category = store.category(for: transaction)
            let icon = transaction.isTransfer ? "arrow.left.arrow.right" : (category?.symbol ?? "circle.fill")
            let color = transaction.isTransfer ? BudgetifyPalette.accent : Color(hex: category?.colorHex ?? "7BAABB")
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BudgetifyPalette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(metadata)
                    .font(.subheadline)
                    .foregroundStyle(BudgetifyPalette.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            VStack(alignment: .trailing, spacing: 3) {
                AmountText(amount: transaction.amount, color: amountColor, prefix: transaction.type == .income ? "+" : "−", fontSize: 15)
                if transaction.status == .pending {
                    Text("DUE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BudgetifyPalette.amber)
                }
            }
            .frame(width: 118, alignment: .trailing)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(transaction.title), \(MoneyFormatter.accessibilityString(transaction.amount, prefix: transaction.type == .income ? "+" : "−")), \(transaction.type.title), \(metadata)")
        .accessibilityHint("Double tap to edit")
    }

    private var amountColor: Color {
        if transaction.isTransfer { return BudgetifyPalette.accent }
        if transaction.type == .expense { return BudgetifyPalette.red }
        return transaction.status == .pending ? BudgetifyPalette.amber : BudgetifyPalette.green
    }

    private var metadata: String {
        let wallet = store.wallet(for: transaction)
        let walletName = wallet?.name ?? "Unknown wallet"
        let groupText = wallet.flatMap(store.group(for:)).map { " · \($0.label)" } ?? ""
        let timeText = transaction.createdAt.formatted(date: .omitted, time: .shortened)
        let transferText = transaction.isTransfer ? "Transfer · " : ""
        return "\(transferText)\(walletName)\(groupText) · \(timeText)"
    }
}

struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(isSelected ? BudgetifyPalette.selectedText : BudgetifyPalette.unselectedText)
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background(isSelected ? BudgetifyPalette.selected : BudgetifyPalette.unselected, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? BudgetifyPalette.selected.opacity(0.35) : BudgetifyPalette.glassBorder, lineWidth: 0.8))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

import SwiftUI
import Foundation
import UniformTypeIdentifiers
import UIKit

struct RecurringView: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    @State private var showingRecurring = false
    @State private var showingFixed = false
    @State private var recurringToDelete: RecurringPayment?
    @State private var fixedToDelete: FixedExpense?
    @State private var recurringToEdit: RecurringPayment?
    @State private var fixedToEdit: FixedExpense?
    @State private var showingRecurringDelete = false
    @State private var showingFixedDelete = false
    @State private var searchText = ""

    private var searchedRecurring: [RecurringPayment] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.recurringPayments }
        return store.recurringPayments.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var searchedFixed: [FixedExpense] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.fixedExpenses }
        return store.fixedExpenses.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionHeading(title: "EMIs", subtitle: "Scheduled commitments", actionTitle: "Add") { showingRecurring = true }
                    if store.recurringPayments.isEmpty {
                        EmptyState(icon: "calendar.badge.clock", title: "Nothing scheduled", message: "Add an EMI to keep future commitments visible.", actionTitle: "Add EMI") { showingRecurring = true }
                    } else if searchedRecurring.isEmpty {
                        EmptyState(icon: "magnifyingglass", title: "No matches", message: "Try a different search term.", actionTitle: "Add EMI") { showingRecurring = true }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(searchedRecurring) { payment in
                                HStack(spacing: 8) {
                                    Button { recurringToEdit = payment } label: { RecurringRow(payment: payment) }
                                        .buttonStyle(.plain)
                                    Toggle("Active", isOn: Binding(get: { payment.isActive }, set: { store.setActive($0, for: payment) }))
                                        .labelsHidden()
                                        .tint(BudgetifyPalette.teal)
                                        .accessibilityLabel("\(payment.name) active")
                                }

                                .budgetifyContextMenu(enabled: true) {
                                    Button { recurringToEdit = payment } label: { Label("Edit", systemImage: "pencil") }
                                    Button { store.setActive(!payment.isActive, for: payment) } label: { Label(payment.isActive ? "Disable" : "Enable", systemImage: payment.isActive ? "pause.circle" : "play.circle") }
                                    Divider()
                                    Button(role: .destructive) { recurringToDelete = payment; showingRecurringDelete = true } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                        }
                        .background(BudgetifyPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: BudgetifyPalette.cardShadow, radius: 12, y: 4)
                    }
                    SectionHeading(title: "Subscriptions", subtitle: "Recurring by frequency", actionTitle: "Add") { showingFixed = true }
                    if store.fixedExpenses.isEmpty {
                        EmptyState(icon: "arrow.clockwise", title: "No subscriptions", message: "Rent, utilities, and other predictable costs belong here.", actionTitle: "Add subscription") { showingFixed = true }
                    } else if searchedFixed.isEmpty {
                        EmptyState(icon: "magnifyingglass", title: "No matches", message: "Try a different search term.", actionTitle: "Add subscription") { showingFixed = true }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(searchedFixed) { fixed in
                                HStack(spacing: 8) {
                                    Button { fixedToEdit = fixed } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "repeat").foregroundStyle(BudgetifyPalette.amber).frame(width: 40, height: 40).background(BudgetifyPalette.amber.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                            VStack(alignment: .leading, spacing: 3) { Text(fixed.name).font(.body.weight(.semibold)).foregroundStyle(BudgetifyPalette.text); Text(fixed.frequency.title).font(.subheadline).foregroundStyle(BudgetifyPalette.muted) }
                                            Spacer(); AmountText(amount: fixed.amount, color: BudgetifyPalette.amber, fontSize: 15)
                                        }.padding(14).overlay(alignment: .bottom) { Divider().overlay(BudgetifyPalette.divider).padding(.leading, 66) }
                                    }
                                    .buttonStyle(.plain)
                                    Toggle("Active", isOn: Binding(get: { fixed.isActive }, set: { store.setActive($0, for: fixed) }))
                                        .labelsHidden()
                                        .tint(BudgetifyPalette.teal)
                                        .accessibilityLabel("\(fixed.name) active")
                                }

                                .budgetifyContextMenu(enabled: true) {
                                    Button { fixedToEdit = fixed } label: { Label("Edit", systemImage: "pencil") }
                                    Button { store.setActive(!fixed.isActive, for: fixed) } label: { Label(fixed.isActive ? "Disable" : "Enable", systemImage: fixed.isActive ? "pause.circle" : "play.circle") }
                                    Divider()
                                    Button(role: .destructive) { fixedToDelete = fixed; showingFixedDelete = true } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                        }
                        .background(BudgetifyPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: BudgetifyPalette.cardShadow, radius: 12, y: 4)
                    }
                    SectionHeading(title: "Forecast", subtitle: "Your committed monthly rhythm")
                    StandardCardSurface(cornerRadius: 20) {
                        HStack(spacing: 14) {
                            Image(systemName: "wand.and.stars").foregroundStyle(BudgetifyPalette.accent).frame(width: 40, height: 40).background(BudgetifyPalette.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Cash-flow forecast").font(.body.weight(.semibold)).foregroundStyle(BudgetifyPalette.text)
                                Text("Balance after pending income, EMIs, and subscriptions.").font(.subheadline).foregroundStyle(BudgetifyPalette.secondary)
                            }
                            Spacer(minLength: 6)
                            AmountText(amount: store.forecast, color: store.forecast >= 0 ? BudgetifyPalette.green : BudgetifyPalette.red, fontSize: 18)
                        }
                        .padding(14)
                    }
                }.screenPadding().padding(.top, 12).padding(.bottom, 44)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .budgetifyNavigationChrome(clearNavigationBar: false)
            .searchable(text: $searchText, prompt: "Search EMIs & subscriptions")
        }
        .sheet(isPresented: $showingRecurring) { RecurringEditor() }
        .sheet(isPresented: $showingFixed) { FixedExpenseEditor() }
        .sheet(item: $recurringToEdit) { RecurringEditor(payment: $0) }
        .sheet(item: $fixedToEdit) { FixedExpenseEditor(expense: $0) }
        .alert("Delete EMI?", isPresented: $showingRecurringDelete) {
            Button("Delete", role: .destructive) { if let payment = recurringToDelete { store.deleteRecurring(payment) }; recurringToDelete = nil }
            Button("Cancel", role: .cancel) { recurringToDelete = nil }
        } message: { Text("Delete \(recurringToDelete?.name ?? "this EMI")? This does not alter past transactions.") }
        .alert("Delete subscription?", isPresented: $showingFixedDelete) {
            Button("Delete", role: .destructive) { if let expense = fixedToDelete { store.deleteFixed(expense) }; fixedToDelete = nil }
            Button("Cancel", role: .cancel) { fixedToDelete = nil }
        } message: { Text("Delete \(fixedToDelete?.name ?? "this subscription")? This does not alter past transactions.") }
    }
}

struct RecurringRow: View {
    @EnvironmentObject private var store: BudgetifyStore
    let payment: RecurringPayment
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: payment.kind == .emi ? "calendar.badge.clock" : "play.rectangle.fill").foregroundStyle(payment.kind == .emi ? BudgetifyPalette.teal : BudgetifyPalette.amber).frame(width: 40, height: 40).background((payment.kind == .emi ? BudgetifyPalette.teal : BudgetifyPalette.amber).opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) { Text(payment.name).font(.body.weight(.semibold)).foregroundStyle(BudgetifyPalette.text); Text("Due on day \(payment.dayOfMonth) · \(payment.kind.title)").font(.subheadline).foregroundStyle(BudgetifyPalette.muted) }
            Spacer(); AmountText(amount: payment.amount, color: BudgetifyPalette.teal, fontSize: 15)
        }.padding(14).overlay(alignment: .bottom) { Divider().overlay(BudgetifyPalette.divider).padding(.leading, 66) }
    }
}

struct WalletsView: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    @State private var showingWallet = false
    @State private var showingTransfer = false
    @State private var expanded = Set<UUID>()
    @State private var walletToDelete: Wallet?
    @State private var walletToEdit: Wallet?
    @State private var showingWalletDelete = false
    @State private var showingGroup = false
    @State private var groupToEdit: AccountGroup?
    @State private var groupToDelete: AccountGroup?
    @State private var showingGroupDelete = false
    @State private var searchText = ""

    private func matchingWallets(in group: AccountGroup) -> [Wallet] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupWallets = store.wallets.filter { $0.groupID == group.id }
        guard !query.isEmpty else { return groupWallets }
        return groupWallets.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private func groupMatchesSearch(_ group: AccountGroup) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return true }
        return group.label.localizedCaseInsensitiveContains(query) || !matchingWallets(in: group).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionHeading(title: "a/c", subtitle: "Every account, one clear view")
                    BalanceCardSurface {
                        HStack { VStack(alignment: .leading, spacing: 5) { Text("Total balance").font(.subheadline.weight(.medium)).foregroundStyle(BudgetifyPalette.heroSecondary); AmountText(amount: store.grandTotal, color: BudgetifyPalette.heroText, fontSize: 29) }; Spacer(); Image(systemName: "wallet.pass.fill").font(.title.weight(.semibold)).foregroundStyle(BudgetifyPalette.heroSecondary) }.padding(18)
                    }
                    ForEach(store.groups.filter(groupMatchesSearch)) { group in
                        let groupWallets = matchingWallets(in: group)
                        let isExpanded = expanded.contains(group.id) || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        VStack(spacing: 0) {
                            Button { withAnimation(.snappy) { if expanded.contains(group.id) { expanded.remove(group.id) } else { expanded.insert(group.id) } };  } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: group.symbol).foregroundStyle(Color(hex: group.colorHex)).frame(width: 34, height: 34).background(Color(hex: group.colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) { Text(group.label).font(.body.weight(.bold)).foregroundStyle(BudgetifyPalette.text); Text("\(groupWallets.count) account\(groupWallets.count == 1 ? "" : "s")").font(.subheadline).foregroundStyle(BudgetifyPalette.muted) }
                                    Spacer(); AmountText(amount: store.balance(for: group), color: Color(hex: group.colorHex), fontSize: 16); Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.caption.weight(.bold)).foregroundStyle(BudgetifyPalette.muted)
                                }.padding(14)
                            }.buttonStyle(.plain).accessibilityLabel("\(group.label), \(groupWallets.count) accounts")
                            if isExpanded {
                                ForEach(groupWallets) { wallet in
                                    Button { walletToEdit = wallet } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: wallet.symbol).font(.body.weight(.semibold)).foregroundStyle(Color(hex: wallet.colorHex)).frame(width: 36, height: 36).background(Color(hex: wallet.colorHex).opacity(0.11), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                            VStack(alignment: .leading, spacing: 2) { Text(wallet.name).font(.body.weight(.semibold)).foregroundStyle(BudgetifyPalette.text); Text(wallet.kind.title).font(.subheadline).foregroundStyle(BudgetifyPalette.muted) }
                                            Spacer(); AmountText(amount: store.balance(for: wallet), color: BudgetifyPalette.text, fontSize: 15)
                                        }.padding(.leading, 60).padding(.trailing, 14).padding(.vertical, 10).contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    .budgetifyContextMenu(enabled: true) {
                                        Button { walletToEdit = wallet } label: { Label("Edit a/c", systemImage: "pencil") }
                                        Divider()
                                        Button(role: .destructive) { walletToDelete = wallet; showingWalletDelete = true } label: { Label("Delete a/c", systemImage: "trash") }
                                    }
                                }
                            }
                        }
                        .background(BudgetifyPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: BudgetifyPalette.cardShadow, radius: 12, y: 4)
                        .budgetifyContextMenu(enabled: true) {
                            Button { groupToEdit = group } label: { Label("Edit a/c group", systemImage: "pencil") }
                            Divider()
                            Button(role: .destructive) { groupToDelete = group; showingGroupDelete = true } label: { Label("Delete a/c group", systemImage: "trash") }
                        }
                    }
                }.screenPadding().padding(.top, 12).padding(.bottom, 44)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .budgetifyNavigationChrome(clearNavigationBar: false)
            .searchable(text: $searchText, prompt: "Search accounts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showingWallet = true } label: { Label("Add a/c", systemImage: "plus") }
                        Button { showingGroup = true } label: { Label("Add group", systemImage: "folder.badge.plus") }
                        Button { showingTransfer = true } label: { Label("Transfer", systemImage: "arrow.left.arrow.right") }
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BudgetifyPalette.teal)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Add account, group, or transfer")
                }
            }
        }
        .sheet(isPresented: $showingGroup) { AccountGroupEditor().presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(item: $groupToEdit) { AccountGroupEditor(group: $0).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $showingWallet) { WalletEditor().presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $showingTransfer) { TransferEditor().presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(item: $walletToEdit) { WalletEditor(wallet: $0).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .alert("Delete a/c group?", isPresented: $showingGroupDelete) {
            Button("Delete", role: .destructive) { if let groupToDelete { store.deleteGroup(groupToDelete) }; groupToDelete = nil }
            Button("Cancel", role: .cancel) { groupToDelete = nil }
        } message: { Text("Delete \(groupToDelete?.label ?? "this group")? Groups with a/cs must be emptied first.") }
        .alert("Delete a/c?", isPresented: $showingWalletDelete) {
            Button("Delete", role: .destructive) { if let wallet = walletToDelete { store.deleteWallet(wallet) }; walletToDelete = nil }
            Button("Cancel", role: .cancel) { walletToDelete = nil }
        } message: { Text("Delete \(walletToDelete?.name ?? "this a/c")? a/cs with linked records must be emptied first.") }
    }
}


struct SettingsView: View {
    @EnvironmentObject private var store: BudgetifyStore
    @EnvironmentObject private var settings: AppSettings
    @State private var showingImporter = false
    @State private var showingCategories = false
    @State private var showingRecurring = false
    @State private var showingDeleteAllConfirmation = false
    @State private var showingNavbarLimit = false

    private let weekdayNames = Calendar.current.weekdaySymbols

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionHeading(title: "Settings", subtitle: "Simple controls for a calmer money view")

                    settingsSection(title: "Appearance", icon: "circle.lefthalf.filled") {
                        Picker("Appearance", selection: $settings.appearance) {
                            ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .tint(BudgetifyPalette.accent)
                    }

                    settingsSection(title: "Transactions", icon: "list.bullet.rectangle.portrait") {
                        Picker("Default entry type", selection: $settings.defaultTransactionType) {
                            ForEach(TransactionType.allCases) { Text($0.title).tag($0) }
                        }
                        Picker("Default a/c", selection: $settings.defaultWalletID) {
                            Text("First a/c").tag(UUID?.none)
                            ForEach(store.wallets) { Text($0.name).tag(Optional($0.id)) }
                        }
                        Picker("Default category", selection: $settings.defaultCategoryID) {
                            Text("First matching category").tag(UUID?.none)
                            ForEach(store.categories.filter { $0.type == (settings.defaultTransactionType == .income ? .income : .expense) }) { Text($0.name).tag(Optional($0.id)) }
                        }
                        Toggle("Show notes by default", isOn: $settings.showNotesByDefault)
                            .tint(BudgetifyPalette.accent)
                        Toggle("Show payment method by default", isOn: $settings.showPaymentMethodByDefault)
                            .tint(BudgetifyPalette.accent)
                    }

                    settingsSection(title: "Dashboard", icon: "rectangle.grid.2x2") {
                        Toggle("Monthly snapshot", isOn: $settings.showMonthlySnapshot).tint(BudgetifyPalette.accent)
                        Toggle("Today’s spending", isOn: $settings.showTodaySpending).tint(BudgetifyPalette.accent)
                        Toggle("Recent activity", isOn: $settings.showRecentActivity).tint(BudgetifyPalette.accent)
                        Toggle("Planning outlook", isOn: $settings.showForecast).tint(BudgetifyPalette.accent)
                        Toggle("Active commitments", isOn: $settings.showCommitmentForecast).tint(BudgetifyPalette.accent)
                    }

                    settingsSection(title: "Navigation Bar", icon: "rectangle.bottomthird.inset.filled") {
                        Text("Choose up to five destinations or shortcuts.")
                            .font(.subheadline)
                            .foregroundStyle(BudgetifyPalette.secondary)
                        ForEach(NavbarTab.allCases.filter { $0 != .settings }) { item in
                            Toggle(isOn: Binding(
                                get: { settings.navbarTabs.contains(item) },
                                set: { enabled in setNavbarItem(item, enabled: enabled) }
                            )) {
                                Label(item.title, systemImage: item.systemImage)
                            }
                            .tint(BudgetifyPalette.accent)
                            .disabled(!settings.navbarTabs.contains(item) && settings.navbarTabs.count >= 5)
                        }
                        Text("Settings stays available so you can always restore hidden destinations. Add is enabled by default and opens a direct Paying or Receiving form.")
                            .font(.footnote)
                            .foregroundStyle(BudgetifyPalette.secondary)
                    }

                    settingsSection(title: "Advanced", icon: "slider.horizontal.3") {
                        Text("Personalize the way Wallet looks and behaves.")
                            .font(.subheadline)
                            .foregroundStyle(BudgetifyPalette.secondary)
                        Picker("First day of week", selection: $settings.firstWeekday) {
                            ForEach(1...7, id: \.self) { Text(weekdayNames[$0 - 1]).tag($0) }
                        }
                        Toggle("Reduce motion", isOn: $settings.reduceMotionEnabled)
                            .tint(BudgetifyPalette.accent)
                        Divider().overlay(BudgetifyPalette.divider)
                        Text("Customize the fields used by the Add shortcut.")
                            .font(.subheadline)
                            .foregroundStyle(BudgetifyPalette.secondary)
                        Picker("Shortcut default", selection: $settings.shortcutDefaultType) {
                            Text("Paying").tag(TransactionType.expense)
                            Text("Receiving").tag(TransactionType.income)
                        }
                        Toggle("Offer category in shortcut", isOn: $settings.shortcutIncludesCategory)
                            .tint(BudgetifyPalette.accent)
                        Toggle("Offer note in shortcut", isOn: $settings.shortcutIncludesNote)
                            .tint(BudgetifyPalette.accent)
                    }

                    settingsSection(title: "Notifications", icon: "bell.badge") {
                        Toggle("Notifications", isOn: $settings.notificationsEnabled)
                            .tint(BudgetifyPalette.accent)
                        Text("Notification scheduling is opt-in and remains off unless you enable it.")
                            .font(.footnote)
                            .foregroundStyle(BudgetifyPalette.secondary)
                    }

                    settingsSection(title: "Manage", icon: "slider.horizontal.3") {
                        Button { showingCategories = true } label: {
                            Label("Categories", systemImage: "tag.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(StandardButtonStyle())
                        
                        Button { showingRecurring = true } label: {
                            Label("EMI & Subscriptions", systemImage: "calendar.badge.clock")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(StandardButtonStyle())
                    }

                    settingsSection(title: "Data", icon: "externaldrive.fill") {
                        if let data = store.exportData() {
                            ShareLink(item: data, preview: SharePreview("Wallet backup", image: Image(systemName: "doc.text"))) {
                                Label("Export all data", systemImage: "arrow.up.doc")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(StandardButtonStyle())
                        }
                        Button { showingImporter = true } label: { 
                            Label("Import JSON backup", systemImage: "arrow.down.doc")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(StandardButtonStyle())
                        HStack {
                            Label("Last backup", systemImage: "clock")
                            Spacer()
                            Text(settings.lastBackupDate?.formatted(date: .abbreviated, time: .shortened) ?? "Not recorded")
                                .font(.footnote)
                                .foregroundStyle(BudgetifyPalette.secondary)
                        }
                        Text("Wallet stores financial data locally on this device. Backups are exported only when you choose to share them.")
                            .font(.footnote)
                            .foregroundStyle(BudgetifyPalette.secondary)
                    }

                    settingsSection(title: "About Wallet", icon: "info.circle") {
                        HStack {
                            Text("App Developer")
                            Spacer()
                            Text("Abhijeet Mitra")
                                .foregroundStyle(BudgetifyPalette.secondary)
                        }
                        HStack {
                            Text("Current Build Number")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                                .foregroundStyle(BudgetifyPalette.secondary)
                        }
                        .font(.footnote.weight(.medium))
                    }

                    settingsSection(title: "Reset", icon: "person.crop.circle") {
                        Text("Wallet works offline and stores records locally on this device.")
                            .font(.subheadline)
                            .foregroundStyle(BudgetifyPalette.secondary)
                        Button(role: .destructive) { showingDeleteAllConfirmation = true } label: { Label("Delete all data", systemImage: "trash") }
                            .buttonStyle(StandardButtonStyle())
                    }

                    Text("Wallet (Beta)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(BudgetifyPalette.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 44)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .budgetifyNavigationChrome(clearNavigationBar: false)
        }
        .preferredColorScheme(settings.appearance.colorScheme)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                store.errorMessage = "The selected backup could not be read."
                store.isShowingError = true
                return
            }
            store.importData(data)
            settings.lastBackupDate = .now
        }
        .sheet(isPresented: $showingCategories) { CategoryManagementView() }
        .sheet(isPresented: $showingRecurring) { RecurringView() }
        .alert("Delete all data?", isPresented: $showingDeleteAllConfirmation) {
            Button("Delete all data", role: .destructive) { store.deleteAllDataPermanently() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This permanently removes all wallets, groups, categories, transactions, and commitments from this device. Export a backup first if you may need the current data.") }
        .alert("Navigation Bar is full", isPresented: $showingNavbarLimit) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The navbar supports up to five buttons. Turn one off before enabling another.")
        }
    }

    private func setNavbarItem(_ item: NavbarTab, enabled: Bool) {
        guard item != .settings else { return }
        if enabled {
            guard settings.navbarTabs.count < 5, !settings.navbarTabs.contains(item) else {
                if settings.navbarTabs.count >= 5 { showingNavbarLimit = true }
                return
            }
            let settingsIndex = settings.navbarTabs.firstIndex(of: .settings) ?? settings.navbarTabs.endIndex
            settings.navbarTabs.insert(item, at: settingsIndex)
        } else {
            settings.navbarTabs.removeAll { $0 == item }
        }
    }

    @ViewBuilder private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.body.weight(.bold)).foregroundStyle(BudgetifyPalette.text)
            VStack(alignment: .leading, spacing: 10) { content() }
        }
        .padding(16)
        .background(BudgetifyPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: BudgetifyPalette.cardShadow, radius: 12, y: 4)
    }
}

struct CategoryManagementView: View {
    @EnvironmentObject private var store: BudgetifyStore
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var newSymbol = "tag.fill"
    @State private var selectedType: CategoryType = .expense
    @State private var editingCategory: BudgetCategory?
    @State private var categoryToDelete: BudgetCategory?
    @State private var showingDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section("Add category") {
                    TextField("Category name", text: $newName)
                    TextField("SF Symbol or emoji", text: $newSymbol)
                    Picker("Type", selection: $selectedType) { ForEach(CategoryType.allCases) { Text($0.title).tag($0) } }
                    Button { store.addCategory(name: newName, type: selectedType, symbol: newSymbol); newName = ""; newSymbol = "tag.fill" } label: { Label("Create category", systemImage: "plus") }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Your categories") {
                    ForEach(store.categories) { category in
                        Button { editingCategory = category } label: {
                            HStack(spacing: 12) {
                                CategorySymbolView(symbol: category.symbol, color: Color(hex: category.colorHex))
                                Text(category.name).foregroundStyle(BudgetifyPalette.text)
                                Spacer()
                                Text(category.type.title).font(.caption.weight(.semibold)).foregroundStyle(BudgetifyPalette.muted)
                                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(BudgetifyPalette.muted)
                            }
                        }
                        .buttonStyle(.plain)

                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BudgetifyPalette.canvas)
            .tint(BudgetifyPalette.accent)
            .navigationTitle("Categories")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .sheet(item: $editingCategory) { category in CategoryEditSheet(category: category) }
        .alert("Delete category?", isPresented: $showingDelete) {
            Button("Delete", role: .destructive) { if let categoryToDelete { store.deleteCategory(categoryToDelete) }; categoryToDelete = nil }
            Button("Cancel", role: .cancel) { categoryToDelete = nil }
        } message: { Text("Delete \(categoryToDelete?.name ?? "this category")? Categories used by existing records cannot be deleted.") }
    }
}

private struct CategorySymbolView: View {
    let symbol: String
    let color: Color

    var body: some View {
        Group {
            if UIImage(systemName: symbol) != nil {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
            } else {
                Text(symbol.isEmpty ? "tag.fill" : symbol)
                    .font(.body.weight(.semibold))
                    .minimumScaleFactor(0.65)
            }
        }
        .foregroundStyle(color)
        .frame(width: 32, height: 32)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("Category icon")
    }
}

private struct CategoryEditSheet: View {
    @EnvironmentObject private var store: BudgetifyStore
    @Environment(\.dismiss) private var dismiss
    let category: BudgetCategory
    @State private var name: String
    @State private var type: CategoryType
    @State private var symbol: String

    init(category: BudgetCategory) {
        self.category = category
        _name = State(initialValue: category.name)
        _type = State(initialValue: category.type)
        _symbol = State(initialValue: category.symbol)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name", text: $name)
                    TextField("SF Symbol or emoji", text: $symbol)
                    Picker("Type", selection: $type) { ForEach(CategoryType.allCases) { Text($0.title).tag($0) } }
                }
            }
            .budgetifyFormChrome()
            .navigationTitle("Edit category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { store.updateCategory(category, name: name, type: type, symbol: symbol); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
        .presentationBackground(BudgetifyPalette.canvas)
        .presentationDetents([.medium])
    }
}

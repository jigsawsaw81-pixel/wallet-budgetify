import SwiftUI
import Foundation
import UniformTypeIdentifiers

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionHeading(title: "Plans", subtitle: "Your committed monthly rhythm")
                    StandardCardSurface(cornerRadius: 22) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "wand.and.stars").foregroundStyle(BudgetifyPalette.purple)
                                Text("Cash-flow forecast").font(.body.weight(.semibold)).foregroundStyle(BudgetifyPalette.text)
                                Spacer()
                                AmountText(amount: store.forecast, color: store.forecast >= 0 ? BudgetifyPalette.green : BudgetifyPalette.red, fontSize: 18)
                            }
                            Text("Balance after pending income, EMIs, and subscriptions.").font(.subheadline).foregroundStyle(BudgetifyPalette.secondary)
                        }
                        .padding(16)
                        .background(BudgetifyPalette.purple.opacity(0.08))
                    }
                    SectionHeading(title: "EMIs", subtitle: "Scheduled commitments", actionTitle: "Add") { showingRecurring = true }
                    if store.recurringPayments.isEmpty {
                        EmptyState(icon: "calendar.badge.clock", title: "Nothing scheduled", message: "Add an EMI to keep future commitments visible.", actionTitle: "Add EMI") { showingRecurring = true }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(store.recurringPayments) { payment in
                                HStack(spacing: 8) {
                                    Button { recurringToEdit = payment } label: { RecurringRow(payment: payment) }
                                        .buttonStyle(.plain)
                                    Toggle("Active", isOn: Binding(get: { payment.isActive }, set: { store.setActive($0, for: payment) }))
                                        .labelsHidden()
                                        .tint(BudgetifyPalette.teal)
                                        .accessibilityLabel("\(payment.name) active")
                                }

                                .budgetifyContextMenu(enabled: settings.holdActionsEnabled) {
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
                    } else {
                        VStack(spacing: 0) {
                            ForEach(store.fixedExpenses) { fixed in
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

                                .budgetifyContextMenu(enabled: settings.holdActionsEnabled) {
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
                }.screenPadding().padding(.top, 12).padding(.bottom, 44)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .budgetifyNavigationChrome(clearNavigationBar: false)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionHeading(title: "a/c", subtitle: "Every account, one clear view")
                    BalanceCardSurface {
                        HStack { VStack(alignment: .leading, spacing: 5) { Text("Total balance").font(.subheadline.weight(.medium)).foregroundStyle(BudgetifyPalette.heroSecondary); AmountText(amount: store.grandTotal, color: BudgetifyPalette.heroText, fontSize: 29) }; Spacer(); Image(systemName: "wallet.pass.fill").font(.title.weight(.semibold)).foregroundStyle(BudgetifyPalette.heroSecondary) }.padding(18)
                    }
                    HStack(spacing: 8) {
                        Button { showingWallet = true } label: { Label("Add a/c", systemImage: "plus") }
                            .buttonStyle(AccountActionButtonStyle(prominent: true))
                        Button { showingGroup = true } label: { Label("Add group", systemImage: "folder.badge.plus") }
                            .buttonStyle(AccountActionButtonStyle(prominent: false))
                        Button { showingTransfer = true } label: { Label("Transfer", systemImage: "arrow.left.arrow.right") }
                            .buttonStyle(AccountActionButtonStyle(prominent: false))
                    }
                    .frame(maxWidth: .infinity)
                    ForEach(store.groups) { group in
                        let groupWallets = store.wallets.filter { $0.groupID == group.id }
                        VStack(spacing: 0) {
                            Button { withAnimation(.snappy) { if expanded.contains(group.id) { expanded.remove(group.id) } else { expanded.insert(group.id) } };  } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: group.symbol).foregroundStyle(Color(hex: group.colorHex)).frame(width: 34, height: 34).background(Color(hex: group.colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) { Text(group.label).font(.body.weight(.bold)).foregroundStyle(BudgetifyPalette.text); Text("\(groupWallets.count) account\(groupWallets.count == 1 ? "" : "s")").font(.subheadline).foregroundStyle(BudgetifyPalette.muted) }
                                    Spacer(); AmountText(amount: store.balance(for: group), color: Color(hex: group.colorHex), fontSize: 16); Image(systemName: expanded.contains(group.id) ? "chevron.up" : "chevron.down").font(.caption.weight(.bold)).foregroundStyle(BudgetifyPalette.muted)
                                }.padding(14)
                            }.buttonStyle(.plain).accessibilityLabel("\(group.label), \(groupWallets.count) accounts")
                            if expanded.contains(group.id) {
                                ForEach(groupWallets) { wallet in
                                    Button { walletToEdit = wallet } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: wallet.symbol).font(.body.weight(.semibold)).foregroundStyle(Color(hex: wallet.colorHex)).frame(width: 36, height: 36).background(Color(hex: wallet.colorHex).opacity(0.11), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                            VStack(alignment: .leading, spacing: 2) { Text(wallet.name).font(.body.weight(.semibold)).foregroundStyle(BudgetifyPalette.text); Text(wallet.kind.title).font(.subheadline).foregroundStyle(BudgetifyPalette.muted) }
                                            Spacer(); AmountText(amount: store.balance(for: wallet), color: BudgetifyPalette.text, fontSize: 15)
                                        }.padding(.leading, 60).padding(.trailing, 14).padding(.vertical, 10).contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    .budgetifyContextMenu(enabled: settings.holdActionsEnabled) {
                                        Button { walletToEdit = wallet } label: { Label("Edit a/c", systemImage: "pencil") }
                                        Divider()
                                        Button(role: .destructive) { walletToDelete = wallet; showingWalletDelete = true } label: { Label("Delete a/c", systemImage: "trash") }
                                    }
                                }
                            }
                        }
                        .background(BudgetifyPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: BudgetifyPalette.cardShadow, radius: 12, y: 4)
                        .budgetifyContextMenu(enabled: settings.holdActionsEnabled) {
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
    @State private var showingResetConfirmation = false
    @State private var showingCategories = false
    @State private var showingRecurring = false
    @State private var showingDeleteAllConfirmation = false
    @State private var showingNavbarLimit = false
    @State private var draggedNavbarItem: NavbarTab?

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

                    settingsSection(title: "Currency", icon: "indianrupeesign.circle") {
                        Picker("Currency", selection: $settings.currencyDisplay) {
                            ForEach(CurrencyDisplay.allCases) { Text($0.title).tag($0) }
                        }
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
                    }

                    settingsSection(title: "First day of week", icon: "calendar") {
                        Picker("First day of week", selection: $settings.firstWeekday) {
                            ForEach(1...7, id: \.self) { Text(weekdayNames[$0 - 1]).tag($0) }
                        }
                    }

                    settingsSection(title: "Interaction", icon: "hand.draw") {
                        Toggle("Press-and-hold actions", isOn: $settings.holdActionsEnabled)
                            .tint(BudgetifyPalette.accent)
                        Text("Press and hold rows for quick edit, enable, and delete actions.")
                            .font(.footnote)
                            .foregroundStyle(BudgetifyPalette.secondary)
                        Toggle("Confirm before deleting", isOn: $settings.deleteConfirmationEnabled)
                            .tint(BudgetifyPalette.accent)
                        Toggle("Show undo after deletion", isOn: $settings.undoAfterDeletionEnabled)
                            .tint(BudgetifyPalette.accent)
                        Toggle("Reduce motion", isOn: $settings.reduceMotionEnabled)
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
                        Text("Choose up to five destinations or shortcuts. Drag enabled items to change their order; changes apply immediately.")
                            .font(.subheadline)
                            .foregroundStyle(BudgetifyPalette.secondary)
                        ForEach(NavbarTab.allCases) { item in
                            Toggle(isOn: Binding(
                                get: { settings.navbarTabs.contains(item) || item == .settings },
                                set: { enabled in setNavbarItem(item, enabled: enabled) }
                            )) {
                                Label(item.title, systemImage: item.systemImage)
                            }
                            .tint(BudgetifyPalette.accent)
                            .disabled(item == .settings || (!settings.navbarTabs.contains(item) && settings.navbarTabs.count >= 5))
                        }
                        Divider().overlay(BudgetifyPalette.divider)
                        Text("Enabled order")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BudgetifyPalette.text)
                        ForEach(settings.navbarTabs) { item in
                            HStack(spacing: 12) {
                                Image(systemName: item.systemImage)
                                    .foregroundStyle(BudgetifyPalette.accent)
                                    .frame(width: 24)
                                Text(item.title)
                                    .foregroundStyle(BudgetifyPalette.text)
                                Spacer()
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(BudgetifyPalette.muted)
                                    .contentShape(Rectangle())
                                    .onDrag {
                                        draggedNavbarItem = item
                                        return NSItemProvider(object: item.rawValue as NSString)
                                    }
                            }
                            .onDrop(of: [.text], delegate: NavbarDropDelegate(target: item, tabs: $settings.navbarTabs, draggedItem: $draggedNavbarItem))
                        }
                        Text("Settings stays available so you can always restore hidden destinations. Add is enabled by default and opens a direct Paying or Receiving form.")
                            .font(.footnote)
                            .foregroundStyle(BudgetifyPalette.secondary)
                    }

                    settingsSection(title: "Advanced", icon: "slider.horizontal.3") {
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
                        Divider().overlay(BudgetifyPalette.divider)
                        Text("Customize shortcut fields used by the Add button.")
                            .font(.subheadline)
                            .foregroundStyle(BudgetifyPalette.secondary)
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

                    settingsSection(title: "Data & Privacy", icon: "externaldrive.fill") {
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

                    settingsSection(title: "About & Help", icon: "questionmark.circle") {
                        if let helpURL = URL(string: "https://help.manus.im") {
                            Link(destination: helpURL) {
                                Label("Help & FAQ", systemImage: "questionmark.circle")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(StandardButtonStyle())
                        }
                        if let privacyURL = URL(string: "https://www.apple.com/legal/privacy/") {
                            Link(destination: privacyURL) {
                                Label("Privacy information", systemImage: "hand.raised")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(StandardButtonStyle())
                        }
                        HStack {
                            Text("Wallet")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(BudgetifyPalette.secondary)
                    }

                    settingsSection(title: "Account", icon: "person.crop.circle") {
                        Text("Wallet works offline and stores records locally on this device.")
                            .font(.subheadline)
                            .foregroundStyle(BudgetifyPalette.secondary)
                        Button(role: .destructive) { showingResetConfirmation = true } label: { Label("Reset demo data", systemImage: "arrow.counterclockwise") }
                            .buttonStyle(StandardButtonStyle())
                        Button(role: .destructive) { showingDeleteAllConfirmation = true } label: { Label("Delete all data", systemImage: "trash") }
                            .buttonStyle(StandardButtonStyle())
                    }

                    Text("Wallet · Liquid Glass ready")
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
        .alert("Reset demo data?", isPresented: $showingResetConfirmation) {
            Button("Reset everything", role: .destructive) { store.resetDemoData() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This removes locally stored records and restores the starter categories and wallet. Export a backup first if you may need the current data.") }
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

private struct NavbarDropDelegate: DropDelegate {
    let target: NavbarTab
    @Binding var tabs: [NavbarTab]
    @Binding var draggedItem: NavbarTab?

    func dropEntered(info: DropInfo) {
        guard let draggedItem, draggedItem != target,
              let sourceIndex = tabs.firstIndex(of: draggedItem),
              tabs.contains(target) else { return }
        withAnimation(.snappy) {
            tabs.remove(at: sourceIndex)
            let adjustedTarget = tabs.firstIndex(of: target) ?? tabs.endIndex
            tabs.insert(draggedItem, at: adjustedTarget)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}

struct CategoryManagementView: View {
    @EnvironmentObject private var store: BudgetifyStore
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var selectedType: CategoryType = .expense
    @State private var editingCategory: BudgetCategory?
    @State private var categoryToDelete: BudgetCategory?
    @State private var showingDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section("Add category") {
                    TextField("Category name", text: $newName)
                    Picker("Type", selection: $selectedType) { ForEach(CategoryType.allCases) { Text($0.title).tag($0) } }
                    Button { store.addCategory(name: newName, type: selectedType); newName = "" } label: { Label("Create category", systemImage: "plus") }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Your categories") {
                    ForEach(store.categories) { category in
                        Button { editingCategory = category } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.symbol).foregroundStyle(Color(hex: category.colorHex)).frame(width: 32, height: 32).background(Color(hex: category.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                Text(category.name).foregroundStyle(BudgetifyPalette.text)
                                Spacer()
                                Text(category.type.title).font(.caption.weight(.semibold)).foregroundStyle(BudgetifyPalette.muted)
                                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(BudgetifyPalette.muted)
                            }
                        }
                        .buttonStyle(.plain)

                    }
                }
                Section("Add category") {
                    TextField("Category name", text: $newName)
                    Picker("Type", selection: $selectedType) { ForEach(CategoryType.allCases) { Text($0.title).tag($0) } }
                    Button { store.addCategory(name: newName, type: selectedType); newName = "" } label: { Label("Create category", systemImage: "plus") }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

private struct CategoryEditSheet: View {
    @EnvironmentObject private var store: BudgetifyStore
    @Environment(\.dismiss) private var dismiss
    let category: BudgetCategory
    @State private var name: String
    @State private var type: CategoryType

    init(category: BudgetCategory) {
        self.category = category
        _name = State(initialValue: category.name)
        _type = State(initialValue: category.type)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) { ForEach(CategoryType.allCases) { Text($0.title).tag($0) } }
                }
            }
            .budgetifyFormChrome()
            .navigationTitle("Edit category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { store.updateCategory(category, name: name, type: type); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
        .presentationBackground(BudgetifyPalette.canvas)
        .presentationDetents([.medium])
    }
}

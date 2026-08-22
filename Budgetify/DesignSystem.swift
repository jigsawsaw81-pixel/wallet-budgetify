import SwiftUI
import UIKit

// MARK: - App settings and semantic palette

enum NavbarTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case transactions
    case accounts
    case recurring
    case quickEntry
    case settings

    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: "Home"
        case .transactions: "Transactions"
        case .accounts: "a/c"
        case .recurring: "Plans"
        case .quickEntry: "Add"
        case .settings: "Settings"
        }
    }
    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .transactions: "list.bullet.rectangle.portrait.fill"
        case .accounts: "wallet.pass.fill"
        case .recurring: "calendar.badge.clock"
        case .quickEntry: "plus.circle.fill"
        case .settings: "gearshape.fill"
        }
    }

    static var defaults: [NavbarTab] { [.home, .transactions, .accounts, .quickEntry, .settings] }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum CurrencyDisplay: String, CaseIterable, Identifiable {
    case inr

    var id: String { rawValue }
    var title: String { "INR · ₹" }
}



enum RowDensity: String, CaseIterable, Identifiable {
    case compact
    case comfortable
    case spacious

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var verticalPadding: CGFloat {
        switch self {
        case .compact: 8
        case .comfortable: 12
        case .spacious: 17
        }
    }
}

enum AccentPreset: String, CaseIterable, Identifiable {
    case teal
    case indigo
    case coral
    case amber
    case emerald

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .teal: Color(hex: "006F6B")
        case .indigo: Color(hex: "4F46A8")
        case .coral: Color(hex: "B83A52")
        case .amber: Color(hex: "9A5B00")
        case .emerald: Color(hex: "087A54")
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var appearance: AppAppearance { didSet { save() } }
    @Published var currencyDisplay: CurrencyDisplay { didSet { save() } }
    @Published var firstWeekday: Int { didSet { save() } }
    @Published var holdActionsEnabled: Bool { didSet { save() } }
    @Published var notificationsEnabled: Bool { didSet { save() } }

    @Published var undoDuration: Double { didSet { save() } }
    @Published var deleteConfirmationEnabled: Bool { didSet { save() } }
    @Published var undoAfterDeletionEnabled: Bool { didSet { save() } }
    @Published var defaultTransactionType: TransactionType { didSet { save() } }
    @Published var defaultWalletID: UUID? { didSet { save() } }
    @Published var defaultCategoryID: UUID? { didSet { save() } }
    @Published var showNotesByDefault: Bool { didSet { save() } }
    @Published var showPaymentMethodByDefault: Bool { didSet { save() } }
    @Published var rowDensity: RowDensity { didSet { save() } }
    @Published var accentPreset: AccentPreset { didSet { save() } }
    @Published var showTodaySpending: Bool { didSet { save() } }
    @Published var showMonthlySnapshot: Bool { didSet { save() } }
    @Published var showRecentActivity: Bool { didSet { save() } }
    @Published var showForecast: Bool { didSet { save() } }
    @Published var showCommitmentForecast: Bool { didSet { save() } }
    @Published var reduceMotionEnabled: Bool { didSet { save() } }
    @Published var lastBackupDate: Date? { didSet { save() } }
    @Published var navbarTabs: [NavbarTab] { didSet { save() } }
    @Published var shortcutDefaultType: TransactionType { didSet { save() } }
    @Published var shortcutIncludesCategory: Bool { didSet { save() } }
    @Published var shortcutIncludesNote: Bool { didSet { save() } }

    init() {
        let defaults = UserDefaults.standard
        appearance = AppAppearance(rawValue: defaults.string(forKey: "budgetify.appearance") ?? "dark") ?? .dark
        let storedCurrency = defaults.string(forKey: "budgetify.currencyDisplay") ?? "inr"
        currencyDisplay = storedCurrency == "symbol" || storedCurrency == "code" ? .inr : (CurrencyDisplay(rawValue: storedCurrency) ?? .inr)
        let weekday = defaults.integer(forKey: "budgetify.firstWeekday")
        firstWeekday = weekday == 0 ? 2 : min(max(weekday, 1), 7)
        holdActionsEnabled = defaults.object(forKey: "budgetify.holdActionsEnabled") as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: "budgetify.notificationsEnabled") as? Bool ?? true

        undoDuration = min(max(defaults.object(forKey: "budgetify.undoDuration") as? Double ?? 4, 2), 10)
        deleteConfirmationEnabled = defaults.object(forKey: "budgetify.deleteConfirmationEnabled") as? Bool ?? true
        undoAfterDeletionEnabled = defaults.object(forKey: "budgetify.undoAfterDeletionEnabled") as? Bool ?? true
        defaultTransactionType = TransactionType(rawValue: defaults.string(forKey: "budgetify.defaultTransactionType") ?? TransactionType.expense.rawValue) ?? .expense
        defaultWalletID = Self.uuid(defaults.string(forKey: "budgetify.defaultWalletID"))
        defaultCategoryID = Self.uuid(defaults.string(forKey: "budgetify.defaultCategoryID"))
        showNotesByDefault = defaults.object(forKey: "budgetify.showNotesByDefault") as? Bool ?? true
        showPaymentMethodByDefault = defaults.object(forKey: "budgetify.showPaymentMethodByDefault") as? Bool ?? true
        rowDensity = RowDensity(rawValue: defaults.string(forKey: "budgetify.rowDensity") ?? "comfortable") ?? .comfortable
        accentPreset = AccentPreset(rawValue: defaults.string(forKey: "budgetify.accentPreset") ?? "teal") ?? .teal
        showTodaySpending = defaults.object(forKey: "budgetify.showTodaySpending") as? Bool ?? true
        showMonthlySnapshot = defaults.object(forKey: "budgetify.showMonthlySnapshot") as? Bool ?? true
        showRecentActivity = defaults.object(forKey: "budgetify.showRecentActivity") as? Bool ?? true
        showForecast = defaults.object(forKey: "budgetify.showForecast") as? Bool ?? true
        showCommitmentForecast = defaults.object(forKey: "budgetify.showCommitmentForecast") as? Bool ?? true
        reduceMotionEnabled = defaults.object(forKey: "budgetify.reduceMotionEnabled") as? Bool ?? false
        lastBackupDate = defaults.object(forKey: "budgetify.lastBackupDate") as? Date
        let storedTabs = (defaults.array(forKey: "budgetify.navbarTabs") as? [String] ?? []).compactMap(NavbarTab.init(rawValue:))
        var sanitizedTabs: [NavbarTab] = []
        for item in storedTabs where !sanitizedTabs.contains(item) { sanitizedTabs.append(item) }
        if sanitizedTabs.isEmpty {
            sanitizedTabs = NavbarTab.defaults
        } else {
            if !sanitizedTabs.contains(.settings) {
                if sanitizedTabs.count == 5 { sanitizedTabs.removeLast() }
                sanitizedTabs.append(.settings)
            }
            if !sanitizedTabs.contains(.quickEntry) && sanitizedTabs.count < 5 {
                let settingsIndex = sanitizedTabs.firstIndex(of: .settings) ?? sanitizedTabs.endIndex
                sanitizedTabs.insert(.quickEntry, at: settingsIndex)
            }
        }
        navbarTabs = Array(sanitizedTabs.prefix(5))
        shortcutDefaultType = TransactionType(rawValue: defaults.string(forKey: "budgetify.shortcutDefaultType") ?? TransactionType.expense.rawValue) ?? .expense
        shortcutIncludesCategory = defaults.object(forKey: "budgetify.shortcutIncludesCategory") as? Bool ?? true
        shortcutIncludesNote = defaults.object(forKey: "budgetify.shortcutIncludesNote") as? Bool ?? true
    }



    private static func uuid(_ value: String?) -> UUID? {
        guard let value else { return nil }
        return UUID(uuidString: value)
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(appearance.rawValue, forKey: "budgetify.appearance")
        defaults.set(currencyDisplay.rawValue, forKey: "budgetify.currencyDisplay")
        defaults.set(firstWeekday, forKey: "budgetify.firstWeekday")
        defaults.set(holdActionsEnabled, forKey: "budgetify.holdActionsEnabled")
        defaults.set(notificationsEnabled, forKey: "budgetify.notificationsEnabled")

        defaults.set(undoDuration, forKey: "budgetify.undoDuration")
        defaults.set(deleteConfirmationEnabled, forKey: "budgetify.deleteConfirmationEnabled")
        defaults.set(undoAfterDeletionEnabled, forKey: "budgetify.undoAfterDeletionEnabled")
        defaults.set(defaultTransactionType.rawValue, forKey: "budgetify.defaultTransactionType")
        defaults.set(defaultWalletID?.uuidString, forKey: "budgetify.defaultWalletID")
        defaults.set(defaultCategoryID?.uuidString, forKey: "budgetify.defaultCategoryID")
        defaults.set(showNotesByDefault, forKey: "budgetify.showNotesByDefault")
        defaults.set(showPaymentMethodByDefault, forKey: "budgetify.showPaymentMethodByDefault")
        defaults.set(rowDensity.rawValue, forKey: "budgetify.rowDensity")
        defaults.set(accentPreset.rawValue, forKey: "budgetify.accentPreset")
        defaults.set(showTodaySpending, forKey: "budgetify.showTodaySpending")
        defaults.set(showMonthlySnapshot, forKey: "budgetify.showMonthlySnapshot")
        defaults.set(showRecentActivity, forKey: "budgetify.showRecentActivity")
        defaults.set(showForecast, forKey: "budgetify.showForecast")
        defaults.set(showCommitmentForecast, forKey: "budgetify.showCommitmentForecast")
        defaults.set(reduceMotionEnabled, forKey: "budgetify.reduceMotionEnabled")
        defaults.set(lastBackupDate, forKey: "budgetify.lastBackupDate")
        defaults.set(navbarTabs.map(\.rawValue), forKey: "budgetify.navbarTabs")
        defaults.set(shortcutDefaultType.rawValue, forKey: "budgetify.shortcutDefaultType")
        defaults.set(shortcutIncludesCategory, forKey: "budgetify.shortcutIncludesCategory")
        defaults.set(shortcutIncludesNote, forKey: "budgetify.shortcutIncludesNote")
    }
}

enum BudgetifyPalette {
    // Core surfaces: bright, cool, and deliberately separated in Light mode.
    static let canvas = Color(light: "F2F1EF", dark: "0B0B0C")
    static let surface = Color(light: "FFFFFF", dark: "1C1C1E")
    static let elevated = Color(light: "EAE8E5", dark: "2C2C2E")
    static let cardShadow = Color(light: "000000", dark: "000000").opacity(0.08)
    static let glassBorder = Color(light: "B8B4AF", dark: "FFFFFF").opacity(0.14)

    // Semantic content and state colors.
    static let accent = Color(light: "6D28D9", dark: "A78BFA")
    static let teal = accent
    static let tealDeep = Color(light: "5B21B6", dark: "C4B5FD")
    static let text = Color(light: "1A1917", dark: "F5F2EE")
    static let secondary = Color(light: "625E58", dark: "B6B2AC")
    static let tertiary = Color(light: "827D76", dark: "85817C")
    static let muted = tertiary
    static let green = Color(light: "087A54", dark: "4CD97B")
    static let red = Color(light: "A51F35", dark: "FF6B5F")
    static let amber = Color(light: "9A6700", dark: "F4C95D")
    static let purple = accent
    static let blue = Color(light: "185BAE", dark: "60A5FA")
    static let debit = red
    static let credit = green
    static let warning = amber
    static let primaryText = text
    static let secondaryText = secondary
    static let tertiaryText = tertiary
    static let selected = accent
    static let selectedText = Color(light: "FFFFFF", dark: "FFFFFF")
    static let unselected = Color(light: "E8E5E1", dark: "242426")
    static let unselectedText = Color(light: "625E58", dark: "B7B3AD")
    static let onAccent = selectedText

    // Dark, high-contrast balance card tokens shared by Home and Wallets.
    static let heroGradientStart = Color(light: "302050", dark: "2B1E46")
    static let heroGradientMid = Color(light: "1D1728", dark: "191426")
    static let heroGradientEnd = Color(light: "141117", dark: "0D0B12")
    static let heroText = Color(light: "F8F5FF", dark: "F8F5FF")
    static let heroSecondary = Color(light: "DDD1FF", dark: "D6C7FF")
    static let heroDivider = Color(light: "BFA8FF", dark: "9070E8").opacity(0.48)
    static let heroInset = Color(light: "000000", dark: "FFFFFF").opacity(0.12)
    static let heroBorder = Color.clear

    static let divider = Color(light: "B6C8D4", dark: "FFFFFF").opacity(0.34)
}

extension Color {
    init(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    init(light: String, dark: String) {
        self.init(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

// MARK: - Rupee formatting and input validation

enum MoneyParseError: LocalizedError, Equatable {
    case empty
    case invalid
    case negative
    case zeroNotAllowed

    var errorDescription: String? {
        switch self {
        case .empty: "Enter an amount."
        case .invalid: "Use numbers with up to two decimal places, such as 1,000.50."
        case .negative: "Amount cannot be negative."
        case .zeroNotAllowed: "Amount must be greater than zero."
        }
    }
}

enum MoneyParser {

    static func parse(_ raw: String, allowsZero: Bool = false) -> Result<Decimal, MoneyParseError> {
        let cleaned = raw
            .filter { !$0.isWhitespace && !$0.isNewline }
            .replacingOccurrences(of: MoneyFormatter.currencySymbol, with: "")
            .replacingOccurrences(of: ",", with: "")

        guard !cleaned.isEmpty else { return .failure(.empty) }
        if cleaned.contains("-") { return .failure(.negative) }
        let pieces = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count <= 2, !pieces.isEmpty, !pieces[0].isEmpty else { return .failure(.invalid) }
        guard pieces[0].allSatisfy({ $0.isNumber }) else { return .failure(.invalid) }
        if pieces.count == 2 {
            guard pieces[1].count <= 2, pieces[1].allSatisfy({ $0.isNumber }) else { return .failure(.invalid) }
        }
        guard let amount = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { return .failure(.invalid) }
        guard amount >= 0 else { return .failure(.negative) }
        guard allowsZero || amount > 0 else { return .failure(.zeroNotAllowed) }
        return .success(amount)
    }
}

enum MoneyFormatter {
    static let currencySymbol = "₹"
    private static let locale = Locale(identifier: "en_IN")

    static func string(_ amount: Decimal, showCurrency: Bool = true, prefix: String = "") -> String {
        let isNegative = amount < .zero
        let sign = prefix.isEmpty ? (isNegative ? "−" : "") : prefix
        let magnitude = isNegative ? -amount : amount
        return sign + (showCurrency ? currencySymbol : "") + numericString(magnitude)
    }

    static func numericString(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = hasFraction(amount) ? 2 : 0
        formatter.maximumFractionDigits = 2
        let number = NSDecimalNumber(decimal: amount)
        return formatter.string(from: number) ?? "0"
    }

    static func accessibilityString(_ amount: Decimal, prefix: String = "") -> String {
        "Amount \(string(amount, prefix: prefix))"
    }

    private static func hasFraction(_ amount: Decimal) -> Bool {
        var input = amount
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &input, 0, .plain)
        return amount != rounded
    }
}

// MARK: - Liquid Glass and shared components

struct StandardCardSurface<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var tint: Color?
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(BudgetifyPalette.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: BudgetifyPalette.cardShadow, radius: 12, y: 4)
    }
}

struct StandardButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, *) {
            configuration.label
                .font(.body.weight(.semibold))
                .foregroundStyle(prominent ? BudgetifyPalette.onAccent : BudgetifyPalette.text)
                .frame(minHeight: 44)
                .padding(.horizontal, 16)
                .background(prominent ? BudgetifyPalette.selected : BudgetifyPalette.unselected, in: Capsule())
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(configuration.isPressed ? 0.86 : 1)
                .animation(.snappy(duration: 0.18), value: configuration.isPressed)
        } else {
            configuration.label
                .font(.body.weight(.semibold))
                .foregroundStyle(prominent ? BudgetifyPalette.onAccent : BudgetifyPalette.text)
                .frame(minHeight: 44)
                .padding(.horizontal, 16)
                .background(prominent ? BudgetifyPalette.selected : BudgetifyPalette.unselected, in: Capsule())
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(configuration.isPressed ? 0.86 : 1)
                .animation(.snappy(duration: 0.18), value: configuration.isPressed)
        }
    }
}

struct AccountActionButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal, 6)
            .foregroundStyle(prominent ? BudgetifyPalette.onAccent : BudgetifyPalette.text)
            .background(prominent ? BudgetifyPalette.selected : BudgetifyPalette.unselected, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(prominent ? BudgetifyPalette.selected.opacity(0.28) : BudgetifyPalette.glassBorder, lineWidth: 0.8))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct RupeeSymbol: View {
    var color: Color = BudgetifyPalette.text
    @ScaledMetric(relativeTo: .body) private var scaledFontSize: CGFloat = 24

    init(color: Color = BudgetifyPalette.text, fontSize: CGFloat = 24) {
        self.color = color
        _scaledFontSize = ScaledMetric(wrappedValue: fontSize, relativeTo: .body)
    }

    var body: some View {
        Image(systemName: "indianrupeesign")
            .font(.system(size: scaledFontSize, weight: .bold))
            .foregroundStyle(color)
            .accessibilityLabel("Indian rupee")
    }
}

struct AmountText: View {
    let amount: Decimal
    var color: Color = BudgetifyPalette.text
    var prefix: String = ""
    @ScaledMetric(relativeTo: .body) private var scaledFontSize: CGFloat = 24

    init(amount: Decimal, color: Color = BudgetifyPalette.text, prefix: String = "", fontSize: CGFloat = 24) {
        self.amount = amount
        self.color = color
        self.prefix = prefix
        _scaledFontSize = ScaledMetric(wrappedValue: fontSize, relativeTo: .body)
    }

    private var sign: String {
        prefix.isEmpty ? (amount < .zero ? "−" : "") : prefix
    }

    private var magnitude: Decimal {
        amount < .zero ? -amount : amount
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            if !sign.isEmpty {
                Text(sign)
            }
            RupeeSymbol(color: color, fontSize: scaledFontSize)
            Text(MoneyFormatter.numericString(magnitude))
        }
        .font(.system(size: scaledFontSize, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(color)
        .minimumScaleFactor(0.68)
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MoneyFormatter.accessibilityString(amount, prefix: prefix))
    }
}

struct MoneyInputField: View {
    @Binding var text: String
    let title: String
    @ScaledMetric(relativeTo: .body) private var scaledFontSize: CGFloat = 22

    init(text: Binding<String>, title: String, fontSize: CGFloat = 22) {
        _text = text
        self.title = title
        _scaledFontSize = ScaledMetric(wrappedValue: fontSize, relativeTo: .body)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            RupeeSymbol(fontSize: scaledFontSize)
            TextField(title, text: $text)
                .keyboardType(.decimalPad)
                .font(.system(size: scaledFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(BudgetifyPalette.text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), Indian rupee amount")
    }
}

struct BalanceCardSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(1)
            .background(LinearGradient(colors: [BudgetifyPalette.heroGradientStart, BudgetifyPalette.heroGradientMid, BudgetifyPalette.heroGradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: BudgetifyPalette.cardShadow, radius: 24, y: 12)
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title3.weight(.bold)).foregroundStyle(BudgetifyPalette.text)
                if let subtitle {
                    Text(subtitle).font(.subheadline.weight(.medium)).foregroundStyle(BudgetifyPalette.secondary)
                }
            }
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderless)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BudgetifyPalette.teal)
                    .frame(minHeight: 44)
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let amount: Decimal
    let color: Color
    var icon: String = "chart.line.uptrend.xyaxis"

    var body: some View {
        StandardCardSurface(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: icon).font(.caption.weight(.bold)).foregroundStyle(color)
                    Text(title.uppercased()).font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(BudgetifyPalette.secondary)
                }
                AmountText(amount: amount, color: color, fontSize: 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(color.opacity(0.08))
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.title2.weight(.semibold)).foregroundStyle(BudgetifyPalette.teal).frame(width: 58, height: 58).background(BudgetifyPalette.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text(title).font(.headline.weight(.bold)).foregroundStyle(BudgetifyPalette.text)
            Text(message).font(.body).multilineTextAlignment(.center).foregroundStyle(BudgetifyPalette.secondary).fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action { Button(actionTitle, action: action).buttonStyle(StandardButtonStyle(prominent: true)) }
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(BudgetifyPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: BudgetifyPalette.cardShadow, radius: 12, y: 4)
    }
}

struct AmbientBackground: View {
    var body: some View {
        ZStack {
            BudgetifyPalette.canvas.ignoresSafeArea()
            Circle().fill(BudgetifyPalette.accent.opacity(0.10)).frame(width: 300).blur(radius: 70).offset(x: 150, y: -260)
            Circle().fill(BudgetifyPalette.red.opacity(0.045)).frame(width: 280).blur(radius: 80).offset(x: -170, y: 300)
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func screenPadding() -> some View { padding(.horizontal, 18) }

    @ViewBuilder
    func budgetifyContextMenu<MenuContent: View>(enabled: Bool, @ViewBuilder content: () -> MenuContent) -> some View {
        if enabled {
            contextMenu { content() }
        } else {
            self
        }
    }

    func budgetifyNavigationChrome(clearNavigationBar: Bool = true) -> some View {
        self.toolbarBackground(clearNavigationBar ? .hidden : .automatic, for: .navigationBar)
            .toolbarColorScheme(nil, for: .navigationBar, .tabBar)
            .tint(BudgetifyPalette.accent)
    }

    func budgetifyFormChrome() -> some View {
        scrollContentBackground(.hidden)
            .background(BudgetifyPalette.canvas)
            .foregroundStyle(BudgetifyPalette.text)
            .tint(BudgetifyPalette.accent)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

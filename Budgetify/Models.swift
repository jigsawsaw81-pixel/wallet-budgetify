import Foundation
import SwiftData

@Model
final class AccountGroup {
    @Attribute(.unique) var id: UUID
    var label: String
    var colorHex: String
    var symbol: String
    var sortOrder: Int

    init(id: UUID = UUID(), label: String, colorHex: String, symbol: String, sortOrder: Int) {
        self.id = id
        self.label = label
        self.colorHex = colorHex
        self.symbol = symbol
        self.sortOrder = sortOrder
    }
}

@Model
final class Wallet {
    @Attribute(.unique) var id: UUID
    var name: String
    var initialBalance: Decimal
    var colorHex: String
    var symbol: String
    var kindRawValue: String
    var groupID: UUID
    var createdAt: Date

    init(id: UUID = UUID(), name: String, initialBalance: Decimal = 0, colorHex: String, symbol: String, kind: WalletKind, groupID: UUID, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.initialBalance = initialBalance
        self.colorHex = colorHex
        self.symbol = symbol
        self.kindRawValue = kind.rawValue
        self.groupID = groupID
        self.createdAt = createdAt
    }

    var kind: WalletKind {
        get { WalletKind(rawValue: kindRawValue) ?? .bank }
        set { kindRawValue = newValue.rawValue }
    }
}

enum WalletKind: String, Codable, CaseIterable, Identifiable {
    case bank
    case cash
    case card

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bank: "Bank"
        case .cash: "Cash"
        case .card: "Card"
        }
    }
}

@Model
final class BudgetCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var symbol: String
    var typeRawValue: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, colorHex: String, symbol: String, type: CategoryType, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.symbol = symbol
        self.typeRawValue = type.rawValue
        self.createdAt = createdAt
    }

    var type: CategoryType {
        get { CategoryType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }
}

enum CategoryType: String, Codable, CaseIterable, Identifiable {
    case expense
    case income
    case recurring

    var id: String { rawValue }
    var title: String {
        switch self {
        case .expense: "Expense"
        case .income: "Income"
        case .recurring: "Recurring"
        }
    }
}

@Model
final class BudgetTransaction {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var title: String
    var categoryID: UUID
    var walletID: UUID
    var typeRawValue: String
    var statusRawValue: String?
    var paymentMethod: String?
    var notes: String?
    var createdAt: Date

    init(id: UUID = UUID(), amount: Decimal, title: String, categoryID: UUID, walletID: UUID, type: TransactionType, status: PaymentStatus? = nil, paymentMethod: String? = nil, notes: String? = nil, createdAt: Date = .now) {
        self.id = id
        self.amount = amount
        self.title = title
        self.categoryID = categoryID
        self.walletID = walletID
        self.typeRawValue = type.rawValue
        self.statusRawValue = status?.rawValue
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.createdAt = createdAt
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    var status: PaymentStatus? {
        get { statusRawValue.flatMap(PaymentStatus.init(rawValue:)) }
        set { statusRawValue = newValue?.rawValue }
    }
}

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense
    case income
    var id: String { rawValue }
    var title: String { rawValue == "expense" ? "Money Out" : "Money In" }
}

enum PaymentStatus: String, Codable, CaseIterable, Identifiable {
    case received = "Received"
    case pending = "Pending"
    var id: String { rawValue }
}

@Model
final class RecurringPayment {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var dayOfMonth: Int
    var walletID: UUID
    var categoryID: UUID
    var kindRawValue: String
    var isActive: Bool
    var createdAt: Date

    init(id: UUID = UUID(), name: String, amount: Decimal, dayOfMonth: Int, walletID: UUID, categoryID: UUID, kind: RecurringKind, isActive: Bool = true, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.amount = amount
        self.dayOfMonth = dayOfMonth
        self.walletID = walletID
        self.categoryID = categoryID
        self.kindRawValue = kind.rawValue
        self.isActive = isActive
        self.createdAt = createdAt
    }

    var kind: RecurringKind {
        get { RecurringKind(rawValue: kindRawValue) ?? .emi }
        set { kindRawValue = newValue.rawValue }
    }
}

enum RecurringKind: String, Codable, CaseIterable, Identifiable {
    case emi
    case subscription
    var id: String { rawValue }
    var title: String { rawValue == "emi" ? "EMI" : "Subscription" }
}

@Model
final class FixedExpense {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var frequencyRawValue: String
    var walletID: UUID
    var categoryID: UUID
    var isActive: Bool
    var createdAt: Date

    init(id: UUID = UUID(), name: String, amount: Decimal, frequency: FixedFrequency, walletID: UUID, categoryID: UUID, isActive: Bool = true, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.amount = amount
        self.frequencyRawValue = frequency.rawValue
        self.walletID = walletID
        self.categoryID = categoryID
        self.isActive = isActive
        self.createdAt = createdAt
    }

    var frequency: FixedFrequency {
        get { FixedFrequency(rawValue: frequencyRawValue) ?? .monthly }
        set { frequencyRawValue = newValue.rawValue }
    }
}

enum FixedFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case annually

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

extension AccountGroup: Identifiable {}
extension Wallet: Identifiable {}
extension BudgetCategory: Identifiable {}
extension BudgetTransaction: Identifiable {}
extension RecurringPayment: Identifiable {}
extension FixedExpense: Identifiable {}

struct BudgetExport: Codable {
    var exportedAt: Date
    var accountGroups: [GroupDTO]
    var wallets: [WalletDTO]
    var categories: [CategoryDTO]
    var transactions: [TransactionDTO]
    var recurringPayments: [RecurringDTO]
    var fixedExpenses: [FixedDTO]
}

struct GroupDTO: Codable { var id: UUID; var label: String; var colorHex: String; var symbol: String; var sortOrder: Int }
struct WalletDTO: Codable { var id: UUID; var name: String; var initialBalance: Decimal; var colorHex: String; var symbol: String; var kind: WalletKind; var groupID: UUID; var createdAt: Date }
struct CategoryDTO: Codable { var id: UUID; var name: String; var colorHex: String; var symbol: String; var type: CategoryType; var createdAt: Date }
struct TransactionDTO: Codable { var id: UUID; var amount: Decimal; var title: String; var categoryID: UUID; var walletID: UUID; var type: TransactionType; var status: PaymentStatus?; var paymentMethod: String?; var notes: String? = nil; var createdAt: Date }
struct RecurringDTO: Codable { var id: UUID; var name: String; var amount: Decimal; var dayOfMonth: Int; var walletID: UUID; var categoryID: UUID; var kind: RecurringKind; var isActive: Bool; var createdAt: Date }
struct FixedDTO: Codable { var id: UUID; var name: String; var amount: Decimal; var frequency: FixedFrequency; var walletID: UUID; var categoryID: UUID; var isActive: Bool; var createdAt: Date }

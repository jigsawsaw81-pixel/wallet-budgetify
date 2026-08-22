import SwiftUI
import SwiftData
import UIKit

@MainActor
enum BudgetifyPersistence {
    static let schema = Schema([
        AccountGroup.self, Wallet.self, BudgetCategory.self, BudgetTransaction.self,
        RecurringPayment.self, FixedExpense.self
    ])

    static func makeContainer() -> ModelContainer {
        let persistentConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        if let persistent = try? ModelContainer(for: schema, configurations: [persistentConfiguration]) {
            return persistent
        }
        if let memory = try? ModelContainer(for: schema, configurations: [memoryConfiguration]) {
            return memory
        }
        preconditionFailure("Wallet could not initialize its local data store")
    }
}

@main
struct BudgetifyApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var store: BudgetifyStore
    @StateObject private var settings: AppSettings

    init() {
        let container = BudgetifyPersistence.makeContainer()
        modelContainer = container
        _store = StateObject(wrappedValue: BudgetifyStore(modelContext: container.mainContext))
        _settings = StateObject(wrappedValue: AppSettings())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .modelContainer(modelContainer)
    }
}

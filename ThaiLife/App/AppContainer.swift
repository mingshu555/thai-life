import SwiftData

enum AppContainer {
    @MainActor static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(StudyStore.modelTypes)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .automatic
        )
        return try ModelContainer(for: schema, configurations: config)
    }
}

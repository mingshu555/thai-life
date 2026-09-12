import Foundation
import SwiftUI
import SwiftData

/// Shared application state injected via Environment.
/// All view models read from this single source of truth.
@MainActor
final class AppState: ObservableObject {
    @Published var modelContainer: ModelContainer?
    @Published var store: StudyStore?
    @Published var contentItems: [ContentItem] = []
    @Published var audioService = AudioPlaybackService()
    @Published var isLoading = true
    @Published var loadError: String?

    var isReady: Bool {
        modelContainer != nil && store != nil && !contentItems.isEmpty
    }

    func initialize() async {
        isLoading = true
        loadError = nil
        do {
            let container = try AppContainer.makeModelContainer()
            let items = try ContentRepository.loadBundled()
            try ContentValidator.validate(items)
            modelContainer = container
            contentItems = items
            store = StudyStore(context: container.mainContext)
            isLoading = false
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }
}

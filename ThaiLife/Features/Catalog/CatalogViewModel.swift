import Foundation
import SwiftUI

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var categories: [ContentCategory] = ContentCategory.allCases
    @Published var items: [ContentItem] = []

    func load(content: [ContentItem]) {
        self.items = content
    }

    func items(for category: ContentCategory) -> [ContentItem] {
        items.filter { $0.category == category }
    }
}

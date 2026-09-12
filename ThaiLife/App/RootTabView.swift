import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "calendar")
                }

            CatalogView()
                .tabItem {
                    Label("课程", systemImage: "book")
                }

            ProgressView()
                .tabItem {
                    Label("进度", systemImage: "chart.bar")
                }
        }
        .tint(ThaiLifeTheme.deepGreen)
    }
}

import SwiftUI
import SwiftData

@main
struct ThaiLifeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.isLoading {
                SwiftUI.ProgressView("正在准备…")
                    .task { await appState.initialize() }
            } else if let error = appState.loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(ThaiLifeTheme.warning)
                    Text("初始化失败")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(ThaiLifeTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        Task { await appState.initialize() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ThaiLifeTheme.warmWhite)
            } else if let container = appState.modelContainer {
                RootTabView()
                    .modelContainer(container)
                    .environmentObject(appState)
                    .environmentObject(AudioPlaybackServiceWrapper(service: appState.audioService))
            }
        }
    }
}

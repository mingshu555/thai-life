import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var desiredRetention: Double = 0.90
    @State private var slowPlaybackEnabled: Bool = false
    @State private var dailyNewLimit: String = "10"
    @State private var isLoaded = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("目标记忆率")
                        Spacer()
                        Text("\(Int(desiredRetention * 100))%")
                            .foregroundColor(ThaiLifeTheme.deepGreen)
                    }
                    Slider(value: $desiredRetention, in: 0.70...0.97, step: 0.01)
                        .onChange(of: desiredRetention) { _, newValue in
                            try? appState.store?.updateSettings(desiredRetention: newValue)
                        }
                    Text("更高的目标会带来更多每日复习")
                        .font(.caption)
                        .foregroundColor(ThaiLifeTheme.textTertiary)
                }

                HStack {
                    Text("每日新词上限")
                    Spacer()
                    TextField("10", text: $dailyNewLimit)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .onChange(of: dailyNewLimit) { _, newValue in
                            if let limit = Int(newValue) {
                                try? appState.store?.updateSettings(dailyNewLimitOverride: limit)
                            }
                        }
                }
            } header: {
                Text("学习设置")
            }

            Section {
                Toggle("慢速发音 (0.75×)", isOn: $slowPlaybackEnabled)
                    .onChange(of: slowPlaybackEnabled) { _, newValue in
                        try? appState.store?.updateSettings(slowPlaybackEnabled: newValue)
                        if newValue {
                            appState.audioService.setRate(0.75)
                        } else {
                            appState.audioService.setRate(1.0)
                        }
                    }
            } header: {
                Text("音频")
            } footer: {
                Text("AI 合成语音 · Google Cloud TTS")
            }

            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(ThaiLifeTheme.textSecondary)
                }
                HStack {
                    Text("内容包")
                    Spacer()
                    Text("v1 · 1,200 单元")
                        .foregroundColor(ThaiLifeTheme.textSecondary)
                }
                HStack {
                    Text("排程算法")
                    Spacer()
                    Text("FSRS-6")
                        .foregroundColor(ThaiLifeTheme.textSecondary)
                }
            } header: {
                Text("关于")
            }
        }
        .navigationTitle("设置")
        .tint(ThaiLifeTheme.deepGreen)
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        guard let store = appState.store, !isLoaded else { return }
        if let settings = try? store.settings() {
            desiredRetention = settings.desiredRetention
            slowPlaybackEnabled = settings.slowPlaybackEnabled
            dailyNewLimit = "\(settings.dailyNewLimitOverride ?? 10)"
            isLoaded = true
        }
    }
}

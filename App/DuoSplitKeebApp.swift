import SwiftUI

@main
struct DuoSplitKeebApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var settings = KeyboardSettings.load()
    @State private var sample = ""
    @FocusState private var sampleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tap here, then switch to Duo Split with the globe key", text: $sample, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($sampleFocused)
                } header: {
                    Text("Try it")
                } footer: {
                    Text("Changes below apply to the keyboard right away, so you can tune it while it's open.")
                }

                Section {
                    Picker("Split keyboard", selection: $settings.splitMode) {
                        ForEach(SplitMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    SettingSlider(title: "Distance from screen edge", value: $settings.edgeMargin,
                                  range: KeyboardSettings.edgeMarginRange, step: 1)
                    SettingSlider(title: "Key width", value: $settings.keyWidth,
                                  range: KeyboardSettings.keyWidthRange, step: 1)
                    SettingSlider(title: "Key height", value: $settings.rowHeight,
                                  range: KeyboardSettings.rowHeightRange, step: 1)
                } header: {
                    Text("Layout")
                } footer: {
                    Text("Each half sits against its own edge of the screen. Lower the distance to push the keys outward; lower the key width to pull G, T, Y, H, V and B closer to your thumbs.")
                }

                Section("Typing") {
                    Toggle("Auto-Correction", isOn: $settings.autocorrect)
                    Toggle("Auto-Capitalization", isOn: $settings.autoCapitalize)
                    Toggle("\u{201C}.\u{201D} Shortcut (double space)", isOn: $settings.doubleSpacePeriod)
                    Toggle("Haptic feedback", isOn: $settings.haptics)
                }

                Section {
                    Text("1. Open Settings → General → Keyboard → Keyboards.")
                    Text("2. Tap Add New Keyboard… and choose Duo Split.")
                    Text("3. Tap Duo Split and turn on Allow Full Access. It's needed so the keyboard can read the settings on this screen and use haptics. The keyboard has no network code.")
                    Text("4. In any text field, tap or hold the globe key to switch to Duo Split.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } header: {
                    Text("Setup")
                }

                Section {
                    Button("Reset to defaults", role: .destructive) {
                        settings = KeyboardSettings()
                    }
                }
            }
            .navigationTitle("Duo Split Keyboard")
            .onChange(of: settings) { _, newValue in
                newValue.save()
                KeyboardSettings.postChanged()
            }
        }
    }
}

private struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.rounded())) pt")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

#Preview {
    ContentView()
}

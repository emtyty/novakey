// SettingsView.swift
// SwiftUI settings window for NovaKey preferences.

import SwiftUI

struct SettingsView: View {
    @State private var fixBrowserAutocomplete: Bool = AppSettings.shared.fixBrowserAutocomplete
    @State private var sendKeyStepByStep: Bool = AppSettings.shared.sendKeyStepByStep

    var body: some View {
        Form {
            Section("Input") {
                Text("Input Method: Telex")
                    .foregroundStyle(.secondary)
                Text("Toggle Hotkey: \(HotkeyManager.currentDescription)")
                    .foregroundStyle(.secondary)
            }

            Section("Compatibility") {
                Toggle("Fix browser autocomplete", isOn: $fixBrowserAutocomplete)
                    .onChange(of: fixBrowserAutocomplete) { _, newValue in
                        AppSettings.shared.fixBrowserAutocomplete = newValue
                    }
                    .help("Send an invisible character before backspaces to prevent browser URL bar autocomplete from interfering.")

                Toggle("Send keys step-by-step", isOn: $sendKeyStepByStep)
                    .onChange(of: sendKeyStepByStep) { _, newValue in
                        AppSettings.shared.sendKeyStepByStep = newValue
                    }
                    .help("Send each character as a separate event. Slower but more compatible with some apps.")
            }

            Section("About") {
                Text("NovaKey v\(AppConstants.version)")
                Text("Vietnamese Input Method for macOS")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 380, height: 400)
    }
}

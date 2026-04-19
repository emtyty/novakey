// AppSettings.swift
// Persists user preferences via UserDefaults.

import Cocoa

/// Observable settings model for the app.
final class AppSettings {

    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Properties

    /// Whether Vietnamese input mode is active. Defaults to true.
    var isVietnameseMode: Bool {
        get { defaults.object(forKey: AppConstants.Defaults.isVietnameseMode) as? Bool ?? true }
        set { defaults.set(newValue, forKey: AppConstants.Defaults.isVietnameseMode) }
    }

    /// Whether to send an invisible character before backspaces to fix browser autocomplete.
    var fixBrowserAutocomplete: Bool {
        get { defaults.object(forKey: AppConstants.Defaults.fixBrowserAutocomplete) as? Bool ?? true }
        set { defaults.set(newValue, forKey: AppConstants.Defaults.fixBrowserAutocomplete) }
    }

    /// Whether to send each character as a separate CGEvent (for compatibility).
    var sendKeyStepByStep: Bool {
        get { defaults.bool(forKey: AppConstants.Defaults.sendKeyStepByStep) }
        set { defaults.set(newValue, forKey: AppConstants.Defaults.sendKeyStepByStep) }
    }

    /// Hotkey keycode for toggling Vietnamese/English.
    var toggleHotkeyKeyCode: UInt16 {
        get {
            let val = defaults.integer(forKey: AppConstants.Defaults.toggleHotkeyKeyCode)
            return val == 0 ? KeyCode.z.rawValue : UInt16(val)
        }
        set { defaults.set(Int(newValue), forKey: AppConstants.Defaults.toggleHotkeyKeyCode) }
    }

    /// Hotkey modifier flags for toggling.
    var toggleHotkeyModifiers: UInt64 {
        get {
            let val = defaults.object(forKey: AppConstants.Defaults.toggleHotkeyModifiers) as? UInt64
            return val ?? CGEventFlags.maskAlternate.rawValue
        }
        set { defaults.set(newValue, forKey: AppConstants.Defaults.toggleHotkeyModifiers) }
    }

    // MARK: - Init

    private init() {
        // Register defaults
        defaults.register(defaults: [
            AppConstants.Defaults.isVietnameseMode: true,
            AppConstants.Defaults.fixBrowserAutocomplete: true,
            AppConstants.Defaults.sendKeyStepByStep: true,
        ])
    }
}

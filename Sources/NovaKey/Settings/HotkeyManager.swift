// HotkeyManager.swift
// Manages the global hotkey for toggling Vietnamese/English mode.

import Cocoa

/// Provides hotkey configuration for the language toggle.
/// The actual detection happens in EventTapManager's callback,
/// this class just manages the settings.
enum HotkeyManager {

    /// Default toggle hotkey: Option + Z
    static let defaultKeyCode: UInt16 = KeyCode.z.rawValue
    static let defaultModifiers: CGEventFlags = .maskAlternate

    /// Human-readable description of a hotkey.
    static func describe(keyCode: UInt16, modifiers: CGEventFlags) -> String {
        var parts: [String] = []

        if modifiers.contains(.maskControl) { parts.append("Ctrl") }
        if modifiers.contains(.maskAlternate) { parts.append("Option") }
        if modifiers.contains(.maskShift) { parts.append("Shift") }
        if modifiers.contains(.maskCommand) { parts.append("Cmd") }

        if let key = KeyCode(rawValue: keyCode), let letter = key.asciiLetter {
            parts.append(String(letter).uppercased())
        } else {
            parts.append("Key(\(keyCode))")
        }

        return parts.joined(separator: "+")
    }

    /// Get the current hotkey description from settings.
    static var currentDescription: String {
        let settings = AppSettings.shared
        return describe(
            keyCode: settings.toggleHotkeyKeyCode,
            modifiers: CGEventFlags(rawValue: settings.toggleHotkeyModifiers)
        )
    }
}

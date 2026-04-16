// StatusBarController.swift
// Manages the NSStatusItem (menu bar icon) showing V/E toggle.

import Cocoa

/// Controls the status bar icon and dropdown menu.
final class StatusBarController {

    private var statusItem: NSStatusItem?
    private let engine: TelexEngine

    /// Callback when user requests to open settings.
    var onOpenSettings: (() -> Void)?

    /// Callback when user quits the app.
    var onQuit: (() -> Void)?

    init(engine: TelexEngine) {
        self.engine = engine
    }

    // MARK: - Setup

    /// Create the status bar item and menu.
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateIcon(isVietnamese: engine.isVietnameseMode)
        buildMenu()
    }

    /// Update the status bar icon to reflect current mode.
    func updateIcon(isVietnamese: Bool) {
        guard let button = statusItem?.button else { return }

        // Use text-based indicator (works without asset catalog)
        let title = isVietnamese ? "V" : "E"
        button.title = title
        button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        button.toolTip = isVietnamese ? "NovaKey: Vietnamese (Telex)" : "NovaKey: English"
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        // Mode toggle
        let modeItem = NSMenuItem(
            title: engine.isVietnameseMode ? "Switch to English" : "Switch to Vietnamese",
            action: #selector(toggleMode),
            keyEquivalent: ""
        )
        modeItem.target = self
        menu.addItem(modeItem)

        // Hotkey hint
        let hotkeyHint = NSMenuItem(
            title: "Toggle: \(HotkeyManager.currentDescription)",
            action: nil,
            keyEquivalent: ""
        )
        hotkeyHint.isEnabled = false
        menu.addItem(hotkeyHint)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Version info
        let versionItem = NSMenuItem(
            title: "NovaKey v\(AppConstants.version)",
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit NovaKey",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleMode() {
        engine.isVietnameseMode.toggle()
        engine.resetSession()
        updateIcon(isVietnamese: engine.isVietnameseMode)
        AppSettings.shared.isVietnameseMode = engine.isVietnameseMode
        buildMenu() // Rebuild to update menu text
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quitApp() {
        onQuit?()
    }
}

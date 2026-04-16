// AppDelegate.swift
// Main application delegate. Sets up the event tap, status bar, and handles lifecycle.

import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var engine: TelexEngine!
    private var eventTapManager: EventTapManager!
    private var statusBarController: StatusBarController!
    private var settingsWindow: NSWindow?

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.setup()
        Log.info("NovaKey starting...")

        // Permission is checked later when event tap starts.
        // Only prompt if it actually fails.

        // Initialize engine
        engine = TelexEngine()
        engine.isVietnameseMode = AppSettings.shared.isVietnameseMode
        Log.info("Engine initialized, Vietnamese mode: \(engine.isVietnameseMode)")

        // Initialize event tap
        guard let tapManager = EventTapManager(engine: engine) else {
            Log.error("Failed to create EventTapManager")
            showFatalError("Failed to initialize event source. Please restart NovaKey.")
            return
        }
        eventTapManager = tapManager
        Log.info("EventTapManager created")

        // Apply settings to event tap
        applySettings()

        // Set up mode change callback
        eventTapManager.onModeChanged = { [weak self] isVietnamese in
            DispatchQueue.main.async {
                self?.statusBarController.updateIcon(isVietnamese: isVietnamese)
                AppSettings.shared.isVietnameseMode = isVietnamese
                Log.info("Mode toggled to: \(isVietnamese ? "Vietnamese" : "English")")
            }
        }

        // Set up status bar
        statusBarController = StatusBarController(engine: engine)
        statusBarController.setup()
        statusBarController.onOpenSettings = { [weak self] in
            self?.showSettings()
        }
        statusBarController.onQuit = {
            NSApplication.shared.terminate(nil)
        }

        // Start event tap
        startEventTap()

        // Register for sleep/wake notifications
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(handleSleep),
                              name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(handleWake),
                              name: NSWorkspace.didWakeNotification, object: nil)

        Log.info("NovaKey started successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventTapManager?.stop()
        Log.info("NovaKey terminated")
    }

    // MARK: - Event Tap

    private func startEventTap() {
        guard eventTapManager != nil else {
            Log.error("Cannot start: EventTapManager is nil")
            return
        }

        if eventTapManager.start() {
            Log.info("Event tap started OK")
        } else {
            Log.error("Event tap FAILED -- requesting permission...")
            AccessibilityPermission.requestAccess()
            AccessibilityPermission.showPermissionAlert()
            pollForPermission()
        }
    }

    /// Poll every 2 seconds until permission is granted, then start the event tap.
    private func pollForPermission() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            if AccessibilityPermission.isGranted {
                timer.invalidate()
                Log.info("Permission granted via polling")
                self?.startEventTap()
            }
        }
    }

    // MARK: - Settings

    private func applySettings() {
        let settings = AppSettings.shared
        eventTapManager.keySender.fixBrowserAutocomplete = settings.fixBrowserAutocomplete
        eventTapManager.keySender.stepByStepMode = settings.sendKeyStepByStep
        eventTapManager.toggleHotkeyKeyCode = settings.toggleHotkeyKeyCode
        eventTapManager.toggleHotkeyModifiers = CGEventFlags(rawValue: settings.toggleHotkeyModifiers)
    }

    private func showSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "NovaKey Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window
    }

    // MARK: - Sleep / Wake

    @objc private func handleSleep(_ notification: Notification) {
        eventTapManager?.stop()
        Log.info("Stopped for sleep")
    }

    @objc private func handleWake(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startEventTap()
        }
    }

    // MARK: - Error Handling

    private func showFatalError(_ message: String) {
        Log.error("Fatal: \(message)")
        let alert = NSAlert()
        alert.messageText = "NovaKey Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")
        alert.runModal()
    }
}

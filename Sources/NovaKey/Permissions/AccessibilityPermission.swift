// AccessibilityPermission.swift
// Checks and requests Input Monitoring permission
// required for CGEvent tap to work.

import Cocoa
import IOKit.hidsystem

enum AccessibilityPermission {

    /// Whether the app has Input Monitoring permission.
    static var hasInputMonitoring: Bool {
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        return access == kIOHIDAccessTypeGranted
    }

    /// Whether the app has Accessibility permission.
    static var hasAccessibility: Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    /// Whether both permissions are granted.
    static var isGranted: Bool {
        hasInputMonitoring && hasAccessibility
    }

    /// Request both Input Monitoring and Accessibility permissions.
    static func requestAccess() {
        // Request Input Monitoring
        let im = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        Log.info("IOHIDRequestAccess(ListenEvent): \(im)")

        // Request Accessibility (shows system prompt)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let ax = AXIsProcessTrustedWithOptions(options)
        Log.info("AXIsProcessTrusted: \(ax)")
    }

    /// Show an alert explaining why permission is needed, then request it.
    static func showPermissionAlert() {
        let im = hasInputMonitoring
        let ax = hasAccessibility

        var needed: [String] = []
        if !im { needed.append("Input Monitoring") }
        if !ax { needed.append("Accessibility") }

        let alert = NSAlert()
        alert.messageText = "NovaKey Needs Permissions"
        alert.informativeText = """
            NovaKey needs the following permissions to work:
            \(needed.joined(separator: " and "))

            Please enable NovaKey in:
            System Settings > Privacy & Security > \(needed.first ?? "Input Monitoring")

            After granting, NovaKey will start automatically.
            You may need to restart NovaKey after granting Accessibility.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Continue Anyway")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if !ax {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            } else {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

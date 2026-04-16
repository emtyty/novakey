// NovaKeyApp.swift
// Main entry point for NovaKey.
// Uses NSApplication directly since this is a menu-bar-only app (LSUIElement).

import Cocoa

// Application entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

// Log.swift
// Simple file-based logger for debugging.
// Writes to /tmp/novakey.log

import Foundation

enum Log {
    private static var logDir: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Logs/NovaKey"
    }
    private static var logFile: String { "\(logDir)/novakey.log" }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func setup() {
        // Create log directory with user-only permissions (0700)
        let fm = FileManager.default
        if !fm.fileExists(atPath: logDir) {
            try? fm.createDirectory(atPath: logDir, withIntermediateDirectories: true)
            // Set directory to owner-only access
            try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: logDir)
        }
        // Clear old log on startup, create with owner-only permissions (0600)
        fm.createFile(atPath: logFile, contents: nil, attributes: [.posixPermissions: 0o600])
        info("=== NovaKey Log Started ===")
    }

    static func info(_ message: String) {
        write("INFO", message)
    }

    static func error(_ message: String) {
        write("ERROR", message)
    }

    /// Debug logs only in DEBUG builds. No-op in release.
    static func debug(_ message: String) {
        #if DEBUG
        write("DEBUG", message)
        #endif
    }

    private static func write(_ level: String, _ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] \(level): \(message)\n"
        if let data = line.data(using: .utf8) {
            if let handle = FileHandle(forWritingAtPath: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        }
    }
}

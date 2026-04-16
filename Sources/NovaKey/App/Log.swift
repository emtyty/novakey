// Log.swift
// Simple file-based logger for debugging.
// Writes to /tmp/novakey.log

import Foundation

enum Log {
    private static let logFile = "/tmp/novakey.log"
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func setup() {
        // Clear old log on startup
        try? "".write(toFile: logFile, atomically: true, encoding: .utf8)
        info("=== NovaKey Log Started ===")
    }

    static func info(_ message: String) {
        write("INFO", message)
    }

    static func error(_ message: String) {
        write("ERROR", message)
    }

    static func debug(_ message: String) {
        write("DEBUG", message)
    }

    private static func write(_ level: String, _ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] \(level): \(message)\n"
        NSLog("NovaKey: %@", message)
        if let data = line.data(using: .utf8) {
            if let handle = FileHandle(forWritingAtPath: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                FileManager.default.createFile(atPath: logFile, contents: data)
            }
        }
    }
}

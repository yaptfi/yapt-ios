//
//  Logger+Extensions.swift
//  Yapt
//
//  Logging infrastructure using os.Logger
//

import Foundation
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.yapt.ios"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let cache = Logger(subsystem: subsystem, category: "cache")
}

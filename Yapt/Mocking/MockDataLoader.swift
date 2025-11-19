//
//  MockDataLoader.swift
//  Yapt
//
//  Utility for loading mock JSON data from bundle
//

import Foundation
import OSLog

enum MockDataLoader {
    /// Load and decode mock JSON data from bundle
    /// - Parameter filename: Name of JSON file (without extension)
    /// - Returns: Decoded object of type T
    static func load<T: Decodable>(_ filename: String) -> T {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "MockData") else {
            Logger.network.error("Failed to find mock data file: \(filename).json")
            fatalError("Failed to find \(filename).json in bundle")
        }

        guard let data = try? Data(contentsOf: url) else {
            Logger.network.error("Failed to load mock data file: \(filename).json")
            fatalError("Failed to load \(filename).json")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first
            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601.date(from: dateString) {
                return date
            }

            // Fallback to standard ISO8601
            let fallbackFormatter = ISO8601DateFormatter()
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }

        do {
            let decoded = try decoder.decode(T.self, from: data)
            Logger.network.debug("Loaded mock data: \(filename).json")
            return decoded
        } catch {
            Logger.network.error("Failed to decode \(filename).json: \(error.localizedDescription)")
            fatalError("Failed to decode \(filename).json: \(error)")
        }
    }

    /// Load mock data with error handling (returns optional)
    /// - Parameter filename: Name of JSON file (without extension)
    /// - Returns: Decoded object of type T, or nil if loading fails
    static func loadOptional<T: Decodable>(_ filename: String) -> T? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "MockData"),
              let data = try? Data(contentsOf: url) else {
            Logger.network.warning("Could not find or load mock data: \(filename).json")
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601.date(from: dateString) {
                return date
            }

            let fallbackFormatter = ISO8601DateFormatter()
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }

        do {
            let decoded = try decoder.decode(T.self, from: data)
            Logger.network.debug("Loaded mock data: \(filename).json")
            return decoded
        } catch {
            Logger.network.warning("Failed to decode \(filename).json: \(error.localizedDescription)")
            return nil
        }
    }
}

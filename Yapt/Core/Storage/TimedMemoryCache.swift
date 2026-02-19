//
//  TimedMemoryCache.swift
//  Yapt
//
//  Thread-safe in-memory cache with TTL support.
//

import Foundation

final class TimedMemoryCache<Value> {
    private let lock = NSLock()
    private var value: Value?
    private var timestamp: Date?

    func valueIfValid(ttl: TimeInterval, now: Date = Date()) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard let value, let timestamp, now.timeIntervalSince(timestamp) < ttl else {
            return nil
        }

        return value
    }

    func store(_ value: Value, at now: Date = Date()) {
        lock.lock()
        self.value = value
        self.timestamp = now
        lock.unlock()
    }

    func clear() {
        lock.lock()
        value = nil
        timestamp = nil
        lock.unlock()
    }
}

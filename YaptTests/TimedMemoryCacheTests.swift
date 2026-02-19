import XCTest
@testable import Yapt

final class TimedMemoryCacheTests: XCTestCase {
    func testReturnsStoredValueWithinTTL() {
        let cache = TimedMemoryCache<String>()
        let storedAt = Date(timeIntervalSince1970: 1_700_000_000)

        cache.store("cached-value", at: storedAt)

        let result = cache.valueIfValid(ttl: 60, now: storedAt.addingTimeInterval(59.9))
        XCTAssertEqual(result, "cached-value")
    }

    func testReturnsNilWhenTTLHasExpired() {
        let cache = TimedMemoryCache<Int>()
        let storedAt = Date(timeIntervalSince1970: 1_700_000_000)

        cache.store(7, at: storedAt)

        XCTAssertNil(cache.valueIfValid(ttl: 60, now: storedAt.addingTimeInterval(60)))
        XCTAssertNil(cache.valueIfValid(ttl: 60, now: storedAt.addingTimeInterval(75)))
    }

    func testClearRemovesStoredValue() {
        let cache = TimedMemoryCache<Double>()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        cache.store(123.45, at: now)
        guard let cachedValue = cache.valueIfValid(ttl: 60, now: now) else {
            return XCTFail("Expected cached value to be available before clearing.")
        }
        XCTAssertEqual(cachedValue, 123.45, accuracy: 0.0001)

        cache.clear()

        XCTAssertNil(cache.valueIfValid(ttl: 60, now: now))
    }
}

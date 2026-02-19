import XCTest
@testable import Yapt

final class PortfolioValueCacheTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PortfolioValueCacheTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        if let suiteName {
            userDefaults?.removePersistentDomain(forName: suiteName)
        }
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testStoresAndLoadsValuesPerActiveUser() {
        let cache = PortfolioValueCache(userDefaults: userDefaults)
        let userA = UUID()
        let userB = UUID()
        let dateA = Date(timeIntervalSince1970: 1_700_000_000)
        let dateB = Date(timeIntervalSince1970: 1_700_000_100)

        cache.setActiveUserID(userA)
        cache.store(totalValue: 100, timestamp: dateA)

        cache.setActiveUserID(userB)
        XCTAssertNil(cache.loadLastValue(), "Different users must not see each other's cached portfolio values.")

        cache.store(totalValue: 200, timestamp: dateB)
        guard let loadedBTotal = cache.loadLastValue()?.totalValue else {
            return XCTFail("Expected a cached value for user B.")
        }
        XCTAssertEqual(loadedBTotal, 200, accuracy: 0.0001)

        cache.setActiveUserID(userA)
        let loadedA = cache.loadLastValue()
        guard let loadedATotal = loadedA?.totalValue else {
            return XCTFail("Expected a cached value for user A.")
        }
        XCTAssertEqual(loadedATotal, 100, accuracy: 0.0001)
        XCTAssertEqual(loadedA?.timestamp, dateA)
    }

    func testClearAllValuesRemovesLegacyAndScopedKeys() {
        let cache = PortfolioValueCache(userDefaults: userDefaults)
        let user = UUID()

        cache.setActiveUserID(user)
        cache.store(totalValue: 321, timestamp: Date())

        // Seed legacy keys to validate migration cleanup path.
        userDefaults.set(111, forKey: "dashboard.lastTotalValue")
        userDefaults.set(Date(), forKey: "dashboard.lastTotalTimestamp")

        cache.clearAllValues()

        cache.setActiveUserID(user)
        XCTAssertNil(cache.loadLastValue())
        XCTAssertNil(userDefaults.object(forKey: "dashboard.lastTotalValue"))
        XCTAssertNil(userDefaults.object(forKey: "dashboard.lastTotalTimestamp"))
    }

    @MainActor
    func testAppEnvironmentClearsPortfolioValueOnLogout() {
        let environment = AppEnvironment()
        let user = User(id: UUID(), username: "test-user", displayName: nil, isAdmin: false)

        environment.sessionManager.login(user: user)
        environment.portfolioValueCache.store(totalValue: 999, timestamp: Date())
        XCTAssertNotNil(environment.portfolioValueCache.loadLastValue())

        environment.sessionManager.logout()

        environment.portfolioValueCache.setActiveUserID(user.id)
        XCTAssertNil(environment.portfolioValueCache.loadLastValue())
    }
}

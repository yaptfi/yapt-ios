import XCTest
@testable import Yapt

final class PositionTypeTests: XCTestCase {
    private struct PositionTypeWrapper: Decodable {
        let positionType: PositionType
    }

    func testKnownPositionTypeTitles() {
        XCTAssertEqual(PositionType.rewards.title, "Rewards")
        XCTAssertEqual(PositionType.savings.title, "Savings")
        XCTAssertEqual(PositionType.fixedIncome.title, "Fixed Income")
    }

    func testUnknownPositionTypeFallsBackToSavings() throws {
        let data = #"{"positionType":"unexpected"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PositionTypeWrapper.self, from: data)

        XCTAssertEqual(decoded.positionType, .savings)
    }
}

import Foundation
import XCTest
@testable import Yapt

final class DiscoveryEventTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func testCompleteEventDefaultsMissingFailedProtocolsToEmptyArray() throws {
        let event = try decode(
            "{\"type\":\"complete\",\"data\":{\"totalPositions\":4}}"
        )

        XCTAssertEqual(event.type, .complete)
        XCTAssertEqual(event.data.totalPositions, 4)
        XCTAssertEqual(event.data.failedProtocols, [])
    }

    func testCompleteEventDecodesFailedProtocols() throws {
        let event = try decode(
            "{\"type\":\"complete\",\"data\":{\"totalPositions\":2,\"failedProtocols\":[\"aave\",\"morpho\"]}}"
        )

        XCTAssertEqual(event.data.failedProtocols, ["aave", "morpho"])
    }

    func testProtocolCompleteDecodesPositionsFoundWithoutIndex() throws {
        let event = try decode(
            "{\"type\":\"protocol_complete\",\"data\":{\"protocol\":\"aave\",\"positionsFound\":2}}"
        )

        XCTAssertEqual(event.type, .protocolComplete)
        XCTAssertEqual(event.data.protocol, "aave")
        XCTAssertEqual(event.data.positionsFound, 2)
        XCTAssertNil(event.data.index)
    }

    func testUnknownEventTypeIsForwardCompatible() throws {
        let event = try decode(
            "{\"type\":\"new_backend_event\",\"data\":{\"message\":42}}"
        )

        XCTAssertEqual(event.type, .unknown)
        XCTAssertNil(event.data.message)
    }

    private func decode(_ json: String) throws -> DiscoveryEvent {
        try decoder.decode(DiscoveryEvent.self, from: Data(json.utf8))
    }
}

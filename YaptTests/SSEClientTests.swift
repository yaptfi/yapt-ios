import Foundation
import Combine
import XCTest
@testable import Yapt

@MainActor
final class SSEClientTests: XCTestCase {
    func testStartStreamingRecreatesEventSubject() {
        let client = SSEClient()
        let beforeID = eventSubjectIdentifier(for: client)

        guard let url = URL(string: "https://example.com/sse") else {
            return XCTFail("Expected a valid test URL")
        }
        let request = URLRequest(url: url)
        client.startStreaming(request: request)
        let afterID = eventSubjectIdentifier(for: client)

        XCTAssertNotNil(beforeID)
        XCTAssertNotNil(afterID)
        XCTAssertNotEqual(beforeID, afterID)

        client.stopStreaming()
    }

    func testStartStreamingUsesSSEAcceptHeaderWithoutAddingContentType() {
        let client = SSEClient()
        guard let url = URL(string: "https://example.com/api/wallets/id/scan") else {
            return XCTFail("Expected a valid test URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        client.startStreaming(request: request)

        let task = dataTask(for: client)
        XCTAssertEqual(task?.originalRequest?.value(forHTTPHeaderField: "Accept"), "text/event-stream")
        XCTAssertNil(task?.originalRequest?.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertNil(task?.originalRequest?.httpBody)

        client.stopStreaming()
    }

    func testProcessLineIgnoresHeartbeatAndBlankFrames() {
        let client = SSEClient()
        var receivedEvents: [String] = []
        let cancellable = client.events.sink(
            receiveCompletion: { _ in },
            receiveValue: { receivedEvents.append($0) }
        )

        client.processLine(": keep-alive")
        client.processLine("")
        client.processLine("   ")

        XCTAssertTrue(receivedEvents.isEmpty)
        withExtendedLifetime(cancellable) {}
    }

    func testProcessLineEmitsOnlyJSONFollowingDataPrefix() {
        let client = SSEClient()
        var receivedEvents: [String] = []
        let cancellable = client.events.sink(
            receiveCompletion: { _ in },
            receiveValue: { receivedEvents.append($0) }
        )

        client.processLine("event: status")
        client.processLine("data: not-json")
        client.processLine("data: {\"type\":\"status\",\"data\":{\"message\":\"Scanning\"}}")

        XCTAssertEqual(
            receivedEvents,
            ["{\"type\":\"status\",\"data\":{\"message\":\"Scanning\"}}"]
        )
        withExtendedLifetime(cancellable) {}
    }

    func testHTTPErrorUsesJSONErrorMessage() {
        let client = SSEClient()
        let body = Data("{\"error\":\"Wallet not found\"}".utf8)

        let error = client.errorForHTTPResponse(statusCode: 404, body: body)

        guard case .serverError(let statusCode, let message) = error else {
            return XCTFail("Expected a server error containing the backend message")
        }
        XCTAssertEqual(statusCode, 404)
        XCTAssertEqual(message, "Wallet not found")
    }

    func testHTTPUnauthorizedMapsToAuthenticationError() {
        let client = SSEClient()
        let body = Data("{\"error\":\"Session expired\"}".utf8)

        let error = client.errorForHTTPResponse(statusCode: 401, body: body)

        guard case .unauthorized = error else {
            return XCTFail("Expected an unauthorized error")
        }
    }

    private func eventSubjectIdentifier(for client: SSEClient) -> ObjectIdentifier? {
        let mirror = Mirror(reflecting: client)
        guard let subject = mirror.children.first(where: { $0.label == "eventSubject" })?.value as AnyObject? else {
            return nil
        }

        return ObjectIdentifier(subject)
    }

    private func dataTask(for client: SSEClient) -> URLSessionDataTask? {
        Mirror(reflecting: client)
            .children
            .first(where: { $0.label == "task" })?
            .value as? URLSessionDataTask
    }
}

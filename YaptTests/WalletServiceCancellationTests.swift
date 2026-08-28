import Combine
import XCTest
@testable import Yapt

private final class StubAPIClient: APIClient {
    override func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        guard let url = URL(string: "https://example.com\(endpoint.path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        return request
    }
}

@MainActor
private final class SpySSEClient: SSEClient {
    private let eventSubject = PassthroughSubject<String, APIError>()
    private(set) var startStreamingCallCount = 0
    private(set) var stopStreamingCallCount = 0
    private(set) var lastRequest: URLRequest?

    override var events: AnyPublisher<String, APIError> {
        eventSubject.eraseToAnyPublisher()
    }

    override func startStreaming(request: URLRequest) {
        startStreamingCallCount += 1
        lastRequest = request
    }

    override func stream(request: URLRequest) -> AnyPublisher<String, APIError> {
        startStreaming(request: request)
        return events
    }

    override func stopStreaming() {
        stopStreamingCallCount += 1
    }

    func send(_ json: String) {
        eventSubject.send(json)
    }

    func finish() {
        eventSubject.send(completion: .finished)
    }
}

@MainActor
final class WalletServiceCancellationTests: XCTestCase {
    func testAddWalletStopsStreamingWhenSubscriptionIsCancelled() {
        let apiClient = StubAPIClient()
        let sseClient = SpySSEClient()
        let service = WalletService(apiClient: apiClient, sseClient: sseClient)

        let cancellable = service
            .addWallet(address: "0x1234567890123456789012345678901234567890", label: nil)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        XCTAssertEqual(sseClient.startStreamingCallCount, 1)
        XCTAssertEqual(sseClient.stopStreamingCallCount, 0)

        cancellable.cancel()

        XCTAssertEqual(sseClient.stopStreamingCallCount, 1)
    }

    func testRescanWalletStopsStreamingWhenSubscriptionIsCancelled() {
        let apiClient = StubAPIClient()
        let sseClient = SpySSEClient()
        let service = WalletService(apiClient: apiClient, sseClient: sseClient)

        let cancellable = service
            .rescanWallet(walletId: UUID())
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        XCTAssertEqual(sseClient.startStreamingCallCount, 1)
        XCTAssertEqual(sseClient.stopStreamingCallCount, 0)

        cancellable.cancel()

        XCTAssertEqual(sseClient.stopStreamingCallCount, 1)
    }

    func testRescanWalletBuildsBodylessUUIDRequest() {
        let apiClient = StubAPIClient()
        let sseClient = SpySSEClient()
        let service = WalletService(apiClient: apiClient, sseClient: sseClient)
        guard let walletID = UUID(uuidString: "18F72180-86BD-4AF4-9C17-53E3B43E09F1") else {
            return XCTFail("Expected a valid wallet UUID")
        }

        let cancellable = service
            .rescanWallet(walletId: walletID)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        XCTAssertEqual(
            sseClient.lastRequest?.url?.path,
            "/api/wallets/18F72180-86BD-4AF4-9C17-53E3B43E09F1/scan"
        )
        XCTAssertEqual(sseClient.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(sseClient.lastRequest?.value(forHTTPHeaderField: "Accept"), "text/event-stream")
        XCTAssertNil(sseClient.lastRequest?.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertNil(sseClient.lastRequest?.httpBody)

        cancellable.cancel()
    }

    func testRescanWalletIgnoresUnknownEventsAndCompletesOnlyAfterCompleteEvent() {
        let apiClient = StubAPIClient()
        let sseClient = SpySSEClient()
        let service = WalletService(apiClient: apiClient, sseClient: sseClient)
        var receivedTypes: [DiscoveryEventType] = []
        var completion: Subscribers.Completion<APIError>?
        let cancellable = service
            .rescanWallet(walletId: UUID())
            .sink(
                receiveCompletion: { completion = $0 },
                receiveValue: { receivedTypes.append($0.type) }
            )

        sseClient.send("{\"type\":\"future_event\",\"data\":{\"newField\":true}}")
        sseClient.send("{\"type\":\"status\",\"data\":{\"message\":\"Joined existing scan\"}}")
        XCTAssertNil(completion)

        sseClient.send("{\"type\":\"complete\",\"data\":{\"totalPositions\":3}}")
        sseClient.finish()

        XCTAssertEqual(receivedTypes, [.status, .complete])
        if case .finished? = completion {
            // Expected successful terminal state.
        } else {
            XCTFail("Expected the rescan to finish after its complete event")
        }
        withExtendedLifetime(cancellable) {}
    }

    func testRescanWalletFailsWhenStreamEndsBeforeCompleteEvent() {
        let apiClient = StubAPIClient()
        let sseClient = SpySSEClient()
        let service = WalletService(apiClient: apiClient, sseClient: sseClient)
        var receivedError: APIError?
        let cancellable = service
            .rescanWallet(walletId: UUID())
            .sink(
                receiveCompletion: {
                    if case .failure(let error) = $0 {
                        receivedError = error
                    }
                },
                receiveValue: { _ in }
            )

        sseClient.send("{\"type\":\"status\",\"data\":{\"message\":\"Scanning\"}}")
        sseClient.finish()

        guard case .eventStreamError(let message)? = receivedError else {
            return XCTFail("Expected a premature stream completion error")
        }
        XCTAssertEqual(message, "The wallet rescan ended before completion")
        withExtendedLifetime(cancellable) {}
    }

    func testRescanWalletTreatsProtocolErrorAsNonfatal() {
        let apiClient = StubAPIClient()
        let sseClient = SpySSEClient()
        let service = WalletService(apiClient: apiClient, sseClient: sseClient)
        var receivedTypes: [DiscoveryEventType] = []
        var receivedError: APIError?
        let cancellable = service
            .rescanWallet(walletId: UUID())
            .sink(
                receiveCompletion: {
                    if case .failure(let error) = $0 {
                        receivedError = error
                    }
                },
                receiveValue: { receivedTypes.append($0.type) }
            )

        sseClient.send("{\"type\":\"protocol_error\",\"data\":{\"protocol\":\"aave\",\"message\":\"Timed out\"}}")
        XCTAssertNil(receivedError)
        sseClient.send("{\"type\":\"complete\",\"data\":{\"totalPositions\":0,\"failedProtocols\":[\"aave\"]}}")
        sseClient.finish()

        XCTAssertEqual(receivedTypes, [.protocolError, .complete])
        XCTAssertNil(receivedError)
        withExtendedLifetime(cancellable) {}
    }

    func testRescanWalletTreatsErrorEventAsFatal() {
        let apiClient = StubAPIClient()
        let sseClient = SpySSEClient()
        let service = WalletService(apiClient: apiClient, sseClient: sseClient)
        var receivedError: APIError?
        let cancellable = service
            .rescanWallet(walletId: UUID())
            .sink(
                receiveCompletion: {
                    if case .failure(let error) = $0 {
                        receivedError = error
                    }
                },
                receiveValue: { _ in }
            )

        sseClient.send("{\"type\":\"error\",\"data\":{\"message\":\"Scan worker failed\"}}")

        guard case .eventStreamError(let message)? = receivedError else {
            return XCTFail("Expected an in-band fatal stream error")
        }
        XCTAssertEqual(message, "Scan worker failed")
        withExtendedLifetime(cancellable) {}
    }
}

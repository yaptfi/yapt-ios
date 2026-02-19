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
    private(set) var startStreamingCallCount = 0
    private(set) var stopStreamingCallCount = 0

    override func startStreaming(request: URLRequest) {
        startStreamingCallCount += 1
    }

    override func stopStreaming() {
        stopStreamingCallCount += 1
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
}

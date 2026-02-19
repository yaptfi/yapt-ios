import Combine
import XCTest
@testable import Yapt

private enum TestBridgeError: Error, Equatable {
    case sampleFailure
}

final class PublisherAsyncBridgeTests: XCTestCase {
    func testAsyncReturnsFirstPublishedValue() async throws {
        let publisher = [11, 22, 33]
            .publisher
            .setFailureType(to: TestBridgeError.self)

        let value = try await publisher.async()

        XCTAssertEqual(value, 11)
    }

    func testAsyncThrowsWhenPublisherFinishesWithoutValue() async {
        let publisher = Empty<Int, TestBridgeError>(completeImmediately: true)
            .eraseToAnyPublisher()

        do {
            _ = try await publisher.async()
            XCTFail("Expected an error when publisher finishes without values.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("without returning a value"))
        }
    }

    func testAsyncPropagatesPublisherFailure() async {
        let publisher = Fail<Int, TestBridgeError>(error: .sampleFailure)
            .eraseToAnyPublisher()

        do {
            _ = try await publisher.async()
            XCTFail("Expected publisher failure to be thrown.")
        } catch let error as TestBridgeError {
            XCTAssertEqual(error, .sampleFailure)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

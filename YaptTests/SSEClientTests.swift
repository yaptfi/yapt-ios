import Foundation
import XCTest
@testable import Yapt

@MainActor
final class SSEClientTests: XCTestCase {
    func testStartStreamingRecreatesEventSubject() {
        let client = SSEClient()
        let beforeID = eventSubjectIdentifier(for: client)

        let request = URLRequest(url: URL(string: "https://example.com/sse")!)
        client.startStreaming(request: request)
        let afterID = eventSubjectIdentifier(for: client)

        XCTAssertNotNil(beforeID)
        XCTAssertNotNil(afterID)
        XCTAssertNotEqual(beforeID, afterID)

        client.stopStreaming()
    }

    private func eventSubjectIdentifier(for client: SSEClient) -> ObjectIdentifier? {
        let mirror = Mirror(reflecting: client)
        guard let subject = mirror.children.first(where: { $0.label == "eventSubject" })?.value as AnyObject? else {
            return nil
        }

        return ObjectIdentifier(subject)
    }
}

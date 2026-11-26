import XCTest
@testable import cal_macro_tracker

final class SupportRequestClientTests: XCTestCase {
    func testBuildsExpectedJSONRequestWithoutEmptyEmail() throws {
        let payload = SupportRequest.make(
            category: .bug,
            message: "Something is not working",
            email: " ",
            appVersion: "1.2",
            build: "42",
            osVersion: "iOS 27.0",
            deviceModel: "iPhone17,1"
        )
        let request = try SupportRequestClient.makeRequest(
            for: payload,
            endpoint: URL(string: "http://127.0.0.1:8788/v1/requests")!
        )
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.timeoutInterval, 15)
        XCTAssertEqual(json["category"] as? String, "Bug")
        XCTAssertNil(json["email"])
        XCTAssertEqual(json["deviceModel"] as? String, "iPhone17,1")
    }

    func testRejectsInvalidMessageAndEmail() {
        let payload = SupportRequest.make(
            category: .question,
            message: "short",
            email: "not-an-email",
            appVersion: "1.2",
            build: "42",
            osVersion: "iOS 27.0",
            deviceModel: "iPhone17,1"
        )
        XCTAssertFalse(payload.isValid)
    }
}

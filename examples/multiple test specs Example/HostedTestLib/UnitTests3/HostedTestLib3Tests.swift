import XCTest

class HostedTestLib3Tests: XCTestCase {
    func test_applicationBundle() {
        XCTAssertNotNil(UIApplication.shared)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String, "App Host")
    }
}

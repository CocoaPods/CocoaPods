import XCTest

class HostedTestLib4Tests: XCTestCase {
    func test_applicationBundle() {
        XCTAssertNotNil(UIApplication.shared)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String, "TestLib-App")
    }
}

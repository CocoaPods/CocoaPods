//
//  Test2.swift
//  TestLib-Unit-Tests
//
//  Created by Jenn Kaplan on 8/6/18.
//

import XCTest

class Test2: XCTestCase {
    func testExample() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, "AppHost-TestLib-Unit-Tests")
        XCTAssertTrue(true)
    }
}

//
//  Test1.swift
//  TestLib-Unit-Tests
//
//  Created by Jenn Kaplan on 8/6/18.
//

import XCTest

class Test1: XCTestCase {    
    func testExample() {
        XCTAssert(["xctest", nil].contains(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String))
        XCTAssertTrue(true)
    }
}

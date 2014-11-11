import UIKit
import XCTest
import orange

class orange_frameworkTests: XCTestCase {
    
    func testExample() {
        let juicer = Juicer()
        XCTAssertEqual(juicer.pressOut([Orange(weight: 1.5), Orange(weight: 0.5)]), Glass(volume: 1.0))
    }
    
}

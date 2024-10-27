import SwiftPod
import ObjCPod

func testImportedThings() {
    print(XYZStruct(name: "string"))
    print(ABC())
}

public func superMeow() -> BCE {
    testImportedThings()
    BCE.meow()
    return BCE()
}

@objc public
class Foo: NSObject {
    @objc public
    init(s: AnyObject) {
        print("Initializing with \(s)")
    }
}

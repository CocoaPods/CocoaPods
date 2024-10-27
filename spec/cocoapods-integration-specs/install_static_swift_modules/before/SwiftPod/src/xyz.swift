import Foundation

private func doTheThing() {
    print("doing the thing!")
}

@objc public
class XYZ : NSObject {
    @objc public
    func doThing(_ x: String) {
        print("do thing \(x):")
        doTheThing()
    }
}

public struct XYZStruct {
    public let name: String

    public init(name: String) { self.name = name }
}

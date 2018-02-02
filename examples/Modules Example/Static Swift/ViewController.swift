#if os(iOS)
import UIKit
typealias BaseViewController = UIViewController
#elseif os(macOS)
import AppKit
typealias BaseViewController = NSViewController
#endif

import ObjCPod
import SwiftPod
import MixedPod

import Alamofire

class ViewController: BaseViewController {

    #if os(iOS)
    override func viewDidAppear(_ animated: Bool) {
        doThings()
    }
    #endif

    func doThings() {
        ABC.bark() // ObjCPod
        print(XYZStruct(name: "")) // SwiftPod
        XYZ().doThing("thiiiing") // SwiftPod
        print(superMeow()) // MixedPod
        BCE.meow() // MixedPod
        print(NSClassFromString("ModelThing")?.copy() as Any) // App, done this way to avoid using a bridging header

        networkRequest()
    }

    func networkRequest() {
        Alamofire.request("https://httpbin.org/get").responseJSON { response in
            print("\n\nAlamofire:\n")
            print("Request: \(String(describing: response.request))")   // original url request

            if let json = response.result.value {
                print("JSON: \(json)") // serialized json response
            }
        }
    }
}


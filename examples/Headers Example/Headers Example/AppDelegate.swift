
import FooHeadersPod
import BarHeadersPod

#if os(iOS)

import UIKit
@UIApplicationMain
class AppDelegate: NSObject, UIApplicationDelegate {

    @IBOutlet weak var window: UIWindow?
}

#else

import Cocoa
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
}

#endif

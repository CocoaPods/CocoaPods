import UIKit
import ByConfig
import HostedTestLib

#if DEBUG
import TestLib
#endif

class ViewController: UIViewController {
    override func viewDidLoad() {
        view.backgroundColor = .purple
    }
}

@UIApplicationMain
class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
            _ = TestLib()
        #endif
        _ = ByConfig()
        _ = HostedTestLib()
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: ViewController())
        window?.makeKeyAndVisible()

        return true
    }
}

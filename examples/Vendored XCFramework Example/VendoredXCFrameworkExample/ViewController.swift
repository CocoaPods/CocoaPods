
import UIKit
import CoconutLib

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let coconut = CoconutObj()
        let alert = UIAlertController(title: "SUCCESS!", message: "Successfully loaded .xcframework dependency type \(type(of: coconut))", preferredStyle: .alert)
        show(alert, sender: self)
    }
}


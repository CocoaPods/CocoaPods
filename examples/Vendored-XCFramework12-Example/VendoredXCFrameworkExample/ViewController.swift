import BananaLib
import CoconutLib
import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        Banana().peel()
        Coconut().makeCoconuts()
    }
}

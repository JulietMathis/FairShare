import UIKit
import CoreData

class LaunchScreenViewController: UIViewController {
    @IBOutlet weak var signInButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    //performs segue to login VC when the "Sign In" button is clicked
    @IBAction func signInButtonClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "toLoginVC", sender: nil)
    }
}





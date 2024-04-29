import UIKit
import FirebaseFirestore
import FirebaseStorage

class ProfileViewController: UIViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var userEmailLabel: UILabel!
    @IBOutlet weak var userPhoneLabel: UILabel!
    
    // MARK: - Properties
    
    var email = ""
    var name = ""
    var phone = ""
    var fetchedPFP = ""
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure profile image view
        profileImage.layer.cornerRadius = profileImage.bounds.width/2
        profileImage.contentMode = .scaleAspectFill
        
        // Check and apply dark mode
        if darkMode == true {
            overrideUserInterfaceStyle = .dark
        }
    }
    
    // Fetches user information from Firestore and populates profile details with fetched information every time the view is about to appear
    override func viewWillAppear(_ animated: Bool) {
        userDocRef.getDocument { (document, error) in
            if let document = document, document.exists {
                self.email = document.get(String("email")) as! String
                self.name = document.get(String("name")) as! String
                self.phone = document.get(String("phone")) as! String
                self.fetchedPFP = document.get(String("pfp")) as! String
                
                // Populate UI with fetched data
                self.userEmailLabel.text = self.email
                self.userNameLabel.text = self.name
                self.userPhoneLabel.text = self.phone
                
                // Load profile image asynchronously from URL
                if self.fetchedPFP != "placeholder" {
                    let url = URL(string: "\(self.fetchedPFP)")!
                    URLSession.shared.dataTask(with: url) { (data, response, error) in
                        guard let imageData = data else { return }
                        
                        DispatchQueue.main.async {
                            self.profileImage.image = UIImage(data: imageData)
                        }
                    }.resume()
                } else {
                    // Set default profile image if no image URL is provided
                    self.profileImage.image = UIImage(named: "defaultProfile")
                }
            } else {
                print("Document does not exist")
            }
        }
    }
    
    // Perform segue to EditProfileViewController
    @IBAction func editProfileButton(_ sender: Any) {
        self.performSegue(withIdentifier: "toEditProfileVC", sender: nil)
    }
}

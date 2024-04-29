import UIKit
import AVFoundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class EditProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var imageField: UIImageView!
    
    // MARK: - Properties
    
    let picker = UIImagePickerController()
    var email = ""
    var name = ""
    var phone = ""
    var pW = ""
    var fetchedPFP = ""
    
    // MARK: - View Lifecycle
    
    // Fetches information from Firestore and populates fields with fetched info
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check and apply dark mode
        if darkMode == true {
            overrideUserInterfaceStyle = .dark
        }
        
        // Configure image picker and text field delegates
        picker.delegate = self
        nameTextField.delegate = self
        phoneTextField.delegate = self
        
        // Configure profile image view
        imageField.layer.cornerRadius = imageField.bounds.width/2
        imageField.contentMode = .scaleAspectFill
        
        // Fetch user information from Firestore
        userDocRef.getDocument { (document, error) in
            if let document = document, document.exists {
                self.email = document.get(String("email")) as! String
                self.name = document.get(String("name")) as! String
                self.phone = document.get(String("phone")) as! String
                self.pW = document.get(String("password")) as! String
                self.fetchedPFP = document.get(String("pfp")) as! String
                
                // Populate UI with fetched data
                self.emailLabel.text = self.email
                self.nameTextField.text = self.name
                self.phoneTextField.text = self.phone
                
                // Load profile image asynchronously from URL
                if self.fetchedPFP != "placeholder" {
                    let url = URL(string: "\(self.fetchedPFP)")!
                    URLSession.shared.dataTask(with: url) { (data, response, error) in
                        guard let imageData = data else { return }
                        DispatchQueue.main.async {
                            self.imageField.image = UIImage(data: imageData)
                        }
                    }.resume()
                } else {
                    // Set default profile image if no image URL is provided
                    self.imageField.image = UIImage(named: "defaultProfile")
                }
            } else {
                print("Document does not exist")
            }
        }
    }
    
    // MARK: - Image Picker
    
    // Presents an action sheet to choose photo upload option
    @IBAction func changeImageButton(_ sender: Any) {
        let controller = UIAlertController(
            title: "Upload a Photo",
            message: "How would you like to upload?",
            preferredStyle: .alert)
        
        // Creates photo library action for alert controller
        let photoLibraryAction = UIAlertAction(title: "From Photo Library", style: .default, handler: { (action) in
            self.picker.allowsEditing = false
            self.picker.sourceType = .photoLibrary
            self.present(self.picker, animated: true)
        })
        controller.addAction(photoLibraryAction)
        
        // Creates take photo action for alert controller
        let takePhotoAction = UIAlertAction(title: "Take Photo", style: .default, handler: { //test this with your phone (somehow...)
            (action) in
            if UIImagePickerController.availableCaptureModes(for: .front) != nil {
                switch AVCaptureDevice.authorizationStatus(for: .video) {
                //Case when access has not yet been granted or denied
                case .notDetermined:
                    AVCaptureDevice.requestAccess(for: .video) {
                        accessGranted in
                        guard accessGranted == true else { return }
                    }
                //case for when access has been granted
                case .authorized:
                    break
                //default case for when access has been denied
                default:
                    print("Cannot access camera")
                    return
                }
                
                self.picker.allowsEditing = false
                self.picker.sourceType = .camera
                self.picker.cameraCaptureMode = .photo
                
                self.present(self.picker, animated: true)
            } else {
                //no front camera
                let alertVC = UIAlertController(
                    title: "No Camera",
                    message: "This device has no camera.",
                    preferredStyle: .alert)
                let okAction = UIAlertAction(title: "Okay", style: .default)
                alertVC.addAction(okAction)
                self.present(alertVC, animated: true)
            }
        })
        controller.addAction(takePhotoAction)
        
        present(controller, animated: true)
    }
    
    // When a photo is selected, update the image field and dismiss the picker
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let chosenImage = info[.originalImage] as? UIImage {
            imageField.contentMode = .scaleAspectFit
            imageField.image = chosenImage
        }
        dismiss(animated: true)
    }
    
    // Dismiss the picker when cancel is clicked
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
    
    // MARK: - Save Changes
    
    // Save changes to Firestore
    @IBAction func saveChangesButton(_ sender: Any) {
        
        //creates a randomID for the image and saves it to firebase storage if there are no errors
        let randomID = UUID.init().uuidString
        let imageRef = Storage.storage().reference(withPath: "pics/\(randomID).jpg")
        guard let imageData = imageField.image?.jpegData(compressionQuality: 0.75) else { return }
        let uploadMetadata = StorageMetadata.init()
        uploadMetadata.contentType = "image/jpeg"
        
        imageRef.putData(imageData, metadata: uploadMetadata) { (downloadMetadata, error) in
            if let error = error {
                print ("Oh no! Got the following error: \(error.localizedDescription)")
                return
            }
            
            imageRef.downloadURL( completion: { (url, error) in
                if let error = error {
                    print("Got the following error generating the URL: \(error.localizedDescription)")
                    return
                }
                //if the fields are empty
                if self.nameTextField.text == nil && self.phoneTextField.text == nil {
                    print("Problem saving: No info to save")
                    return
                    
                //updates the user's document in firestore if neither of the fields are left blank
                } else if self.nameTextField.text != nil && self.phoneTextField.text != nil {
                    userDocRef = Firestore.firestore().document("users/\(userID)")
                    userDocRef.getDocument { (document, error) in
                        if let document = document, document.exists {
                            userDocRef.updateData([
                                "name": self.nameTextField.text!,
                                "phone": self.phoneTextField.text!,
                                "pfp": "\(url!.absoluteString)"])
                            self.performSegue(withIdentifier: "editProfileToProfileVC", sender: self)
                        } else if let error = error {
                            print("\(error.localizedDescription)")
                        }
                    }
                }
            })
        }
    }
    
    // MARK: - Delete Profile
    
    // Delete user's profile and related data
    @IBAction func deleteProfileButtonClicked(_ sender: Any) {
        let controller = UIAlertController(
            title: "Delete Profile",
            message: "Are you sure you want to delete your profile?",
            preferredStyle: .actionSheet)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {
            (action) in print("Cancel action")
        })
        controller.addAction(cancelAction)
        
        let destroyAction = UIAlertAction(title: "Delete", style: .destructive, handler: {
            (action) in
            //delete everything needed from firebase
            //Then segue back to loginVC, and set userID = ""
            
            let dispatchGroup0 = DispatchGroup()
            let dispatchGroup = DispatchGroup()
            let dispatchGroup2 = DispatchGroup()
            let dispatchGroup3 = DispatchGroup()

            dispatchGroup0.enter()
            
            userDocRef = Firestore.firestore().document("users/\(userID)")
            userDocRef.getDocument { [weak self] (document, error) in
                guard let self = self else { return }
                if let document = document, document.exists {
                    var groups = document.get(String("groups")) as? Array<String>
                    if groups != [] {
                        for group in groups! {
                            groupDocRef = Firestore.firestore().document("groups/\(group)")
                            
                            dispatchGroup.enter()
                            
                            groupDocRef.getDocument { [weak self] (groupDocument, error) in
                                guard let self = self else { return }
                                if let groupDocument = groupDocument, groupDocument.exists {
                                    var trips = groupDocument.get(String("trips")) as? Array<String>
                                    if trips != [] {
                                        for trip in trips! {
                                            tripDocRef = Firestore.firestore().document("groups/\(group)/trips/\(trip)")
                                            
                                            dispatchGroup2.enter()
                                            
                                            tripDocRef.getDocument { [weak self] (tripDocument, error) in
                                                guard let self = self else { return }
                                                if let tripDocument = tripDocument, tripDocument.exists {
                                                    var items = tripDocument.get(String("itemIDs")) as? Array<String>
                                                    if items != [] {
                                                        for item in items! {
                                                            itemDocRef = Firestore.firestore().document("groups/\(group)/trips/\(trip)/items/\(item)")
                                                            
                                                            dispatchGroup3.enter()
                                                            
                                                            itemDocRef.getDocument { [weak self] (itemDocument, error) in
                                                                guard let self = self else { return }
                                                                if let itemDocument = itemDocument, itemDocument.exists {
                                                                    var done = itemDocument.get(String("done")) as? Bool
                                                                    var targetVotes = itemDocument.get(String("targetVotes")) as? Int
                                                                    var users = itemDocument.get(String("users")) as? Array<String>
                                                                    var voters = itemDocument.get(String("voters")) as? Array<String>
                                                                    var votes = itemDocument.get(String("votes")) as? Int
                                                                    
                                                                    targetVotes! -= 1
                                                                    
                                                                    if users!.contains(userID) {
                                                                        users!.removeAll { value in
                                                                          return value == userID
                                                                        }
                                                                    }
                                                                    
                                                                    if voters!.contains(userID) {
                                                                        votes! -= 1
                                                                        voters!.removeAll { value in
                                                                          return value == userID
                                                                        }
                                                                    }
                                                                    
                                                                    if done == false {
                                                                        if targetVotes == votes {
                                                                            done = true
                                                                        }
                                                                    }
                                                                    
                                                                    itemDocRef.updateData([
                                                                        "voters":  voters!,
                                                                        "users":  users!,
                                                                        "votes": votes!,
                                                                        "targetVotes": targetVotes!,
                                                                        "done": done!
                                                                    ])
                                                                }
                                                            }
                                                        }
                                                    }//leave itemLoop
                                                    
                                                    dispatchGroup3.leave()
                                                    
                                                    dispatchGroup3.notify(queue: .main) {
                                                        var owner = tripDocument.get(String("owner")) as? String
                                                        var usersInt = tripDocument.get(String("usersInt")) as? Int
                                                        var users = tripDocument.get(String("users")) as? Array<String>
                                                        
                                                        if owner! == userID {
                                                            owner = "Owner's account deleted"
                                                        }
                                                        
                                                        if users!.contains(userID) {
                                                            users!.removeAll { value in
                                                                return value == userID
                                                            }
                                                            usersInt! -= 1
                                                        }
                                                        
                                                        tripDocRef.updateData([
                                                            "owner":  owner!,
                                                            "users":  users!,
                                                            "usersInt": usersInt!
                                                        ])
                                                    }
                                                } //this closes the if let tripDoc exists
                                                
                                                dispatchGroup2.leave()
                                            }
                                        }
                                    }
                                    dispatchGroup2.notify(queue: .main) {
                                        var members = groupDocument.get(String("members")) as? Array<String>
                                        
                                        if members!.contains(userID) {
                                            members!.removeAll { value in
                                                return value == userID
                                            }
                                        }
                                        
                                        groupDocRef.updateData(["members":  members!])
                                    }
                                }//closes the if let groupDoc exists
                                
                                dispatchGroup.leave()
                            }
                            
                        }
                    }
                    dispatchGroup.notify(queue: .main) {
                        userDocRef.updateData([
                            "name":  "user Deleted",
                            "groups":  [],
                        ])
                    }
                }//closes if let userDoc exists
            }
            
            dispatchGroup0.leave()
            
            dispatchGroup0.notify(queue: .main) {
                userDocRef.updateData([
                    "name":  "user Deleted",
                    "groups":  [],
                ])
                Auth.auth().currentUser!.delete()
            }
            self.performSegue(withIdentifier: "deleteAccountSegue", sender: self)
        })
        controller.addAction(destroyAction)
        
        present(controller, animated: true)
    }
}

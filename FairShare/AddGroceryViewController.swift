import UIKit
import FirebaseFirestore

class AddGroceryViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {

    // MARK: - Outlets
    
    @IBOutlet weak var groceryTitleTextField: UITextField!
    @IBOutlet weak var groceryPriceTextField: UITextField!
    @IBOutlet weak var statusLabel: UILabel!

    // MARK: - Properties
    
    let picker = UIImagePickerController()
    let tripID = tripStack.peek()
    let groupID = groupStack.peek()
    var targetVotesVar = 0

    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check and apply dark mode
        if darkMode == true {
            overrideUserInterfaceStyle = .dark
        }
        
        // Set delegates for text fields
        groceryTitleTextField.delegate = self
        groceryPriceTextField.delegate = self
    }

    // MARK: - UIImagePickerControllerDelegate Method
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
    
    // MARK: - Button Actions
    
    @IBAction func saveGroceryButton(_ sender: Any) {
        let grocID = UUID.init().uuidString
        let groceryTitle = groceryTitleTextField.text
        let groceryPrice = groceryPriceTextField.text

        guard let title = groceryTitle, let price = groceryPrice, !title.isEmpty, !price.isEmpty else {
            self.statusLabel.text = "Fields cannot be left blank"
            return
        }

        if checkString(string: price) {
            let tripDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(self.tripID)")

            tripDocRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    var tempPrices = document.get(String("prices")) as? [String] ?? []
                    tempPrices.append(groceryPrice!)
                    let totalPriceCheck = document.get(String("totalPrice")) as! Double
                    let usersInt = document.get(String("usersInt")) as! Int
                    self.targetVotesVar = usersInt
                    
                    tripDocRef.updateData([
                        "items": FieldValue.arrayUnion([title]),
                        "prices": tempPrices,
                        "itemIDs": FieldValue.arrayUnion([grocID]),
                        "totalPrice": totalPriceCheck + (Double(price)! * 1.0825)
                    ])

                    let itemDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(self.tripID)/items/\(grocID)")


                    let dataToSave: [String: Any] = ["price": price, "users": [], "votes": 0, "voters": [], "priceWTax": (Double(price)! * 1.0825),"done": false, "targetVotes": self.targetVotesVar]
                    //find a way to update userInt(trips) var AND targetVotesVar(items) when new member joins group/member leaves
                    itemDocRef.setData(dataToSave) { (error) in
                        if let error = error {
                            print("\(error.localizedDescription)")
                        }
                    }

                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "backToDisplayGroceryVC", sender: self)
                    }
                }
            }
        } else {
            self.statusLabel.text = "Only numbers and decimal points allowed in the price text field"
        }
    }

    // MARK: - Navigation Button Actions
    
    @IBAction func homeButtonPressed(_ sender: Any) {
        tripStack.pop()
        groupStack.pop()
        self.performSegue(withIdentifier: "addGroceryVCToMainVC", sender: self)
    }

    @IBAction func profileButtonPressed(_ sender: Any) {
        tripStack.pop()
        groupStack.pop()
        self.performSegue(withIdentifier: "addGroceryVCToProfile", sender: self)
    }
    
    @IBAction func settingsButtonPressed(_ sender: Any) {
        tripStack.pop()
        groupStack.pop()
        self.performSegue(withIdentifier: "addGroceryVCToSettings", sender: self)
    }
    
    @IBAction func backButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "backToDisplayGroceryVC", sender: self)
    }

    // MARK: - Helper Methods
    
    let priceChars = "0.123456789"

    // Check if the string is a valid number
    func checkString(string: String) -> Bool {
        let digits = CharacterSet(charactersIn: priceChars)
        let stringSet = CharacterSet(charactersIn: string)
        return digits.isSuperset(of: stringSet)
    }

    // MARK: - UITextFieldDelegate Methods
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}

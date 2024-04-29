import UIKit
import FirebaseFirestore
import FirebaseAuth

class ViewController: UIViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var joinExistingGroupButton: UIButton!
    @IBOutlet weak var createNewGroupButton: UIButton!
    
    // MARK: - Properties
    
    var counter: Double = 0
    var groups: [String] = []
    var groupTitle = "Replace"
    
    // MARK: - View Lifecycle
    
    // Creates buttons for each group the user is in based on data from Firestore
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check and apply dark mode
        if darkMode == true {
            overrideUserInterfaceStyle = .dark
        }
        
        // Calculate button layout parameters
        let maxY1 = joinExistingGroupButton.frame.maxY
        let minY2 = createNewGroupButton.frame.minY
        let maxY2 = createNewGroupButton.frame.maxY
        let minX = joinExistingGroupButton.frame.minX
        let height = joinExistingGroupButton.frame.height
        let width = joinExistingGroupButton.frame.width
        let spacing = minY2 - maxY1
        
        // Fetch user's groups from Firestore and create buttons
        let userDocRef = Firestore.firestore().document("users/\(userID)")
        userDocRef.getDocument { (document, error) in
            if let document = document, document.exists {
                self.groups = document.get(String("groups")) as! Array<String>
                
                for group in self.groups {
                    self.counter = self.counter + 1
                    let myButton = UIButton(type: .system)
                    
                    // Position Button
                    let mySpace = self.counter * spacing
                    let buttonSpace = (self.counter) * height
                    
                    myButton.frame = CGRect(x: minX, y: maxY2 + mySpace + buttonSpace, width: width, height: height)
                    myButton.layer.cornerRadius = height / 4
                    myButton.titleLabel!.font = UIFont.systemFont(ofSize: 17.0, weight: UIFont.Weight.regular)
                    myButton.tag = Int(self.counter) - 1
                    
                    // Set text on button
                    let groupDocRef = Firestore.firestore().document("groups/\(group)")
                    groupDocRef.getDocument { (document, error) in
                        if let document = document, document.exists {
                            self.groupTitle = document.get(String("title")) as! String
                            myButton.setTitle("\(self.groupTitle)", for: .normal)
                            myButton.titleLabel?.tintColor = myDG
                            myButton.backgroundColor = mySLG
                            
                            // Set button action
                            myButton.addTarget(self, action: #selector(self.buttonAction(_:)), for: .touchUpInside)
                            
                            self.view.addSubview(myButton)
                            self.view = self.view
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Button Actions
    
    // When a group's button is pressed, the group to which it corresponds is identified by the tag
    // and pushed onto the groupStack, and the segue to GroupInfoViewController occurs.
    @objc func buttonAction(_ sender:UIButton!) {
        let tag = sender.tag
        let groupCode = self.groups[tag]
        groupStack.push(String(groupCode))
        self.performSegue(withIdentifier: "toGroupVC", sender: self)
    }
    
    // MARK: - Group Operations
    
    // When the "Join Existing Group" button is pressed, a UIAlertController appears
    // where the user types in the code of a group they'd like to join.
    @IBAction func joinExistingGroup(_ sender: Any) {
        let controller = UIAlertController(
            title: "Join a Group",
            message: "Type the group's join code here:",
            preferredStyle: .alert)
        
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        controller.addTextField(configurationHandler: {
            (textField) in textField.placeholder = "Enter Group Join Code"
        } )
        
        controller.addAction(UIAlertAction(title: "Join Group", style: .default, handler: { action in
            let enteredText = Int(controller.textFields![0].text!)
            let groupDocRef = Firestore.firestore().document("groups/\(enteredText ?? 0)")

            // Update group's members
            groupDocRef.updateData(["members": FieldValue.arrayUnion(["\(userID)"])]) { error in
                if let error = error {
                    print("Error joining group: \(error.localizedDescription)")
                } else {
                    // Update user's groups
                    let userDocRef = Firestore.firestore().document("users/\(userID)")
                    userDocRef.updateData(["groups": FieldValue.arrayUnion(["\(enteredText ?? 0)"])]) { userError in
                        if let userError = userError {
                            print("Error updating user's groups: \(userError.localizedDescription)")
                        } else {

                            // Retrieve the updated group data
                            groupDocRef.getDocument { groupDocument, groupError in
                                if let groupDocument = groupDocument, groupDocument.exists {
                                    let members = groupDocument.get("members") as? [String] ?? []
                                    let trips = groupDocument.get("trips") as? [String] ?? []

                                    // Update usersInt in each trip
                                    for trip in trips {
                                        let tripDocRef = Firestore.firestore().document("groups/\(enteredText ?? 0)/trips/\(trip)")
                                        tripDocRef.updateData(["usersInt": members.count])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }))
        
        present(controller, animated: true)
    }
    
    // A UIAlertController is presented where the user can type in the name of their group,
    // and then the group is created.
    @IBAction func createNewGroup(_ sender: Any) {
        let groupID = Int.random(in: 100000 ... 999999)
        
        let controller = UIAlertController(
            title: "New Group",
            message: "What would you like to name your group?",
            preferredStyle: .alert)
        
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        controller.addTextField(configurationHandler: {
            (textField) in textField.placeholder = "Enter Group Name"
        } )
        
        controller.addAction(UIAlertAction(title: "Create Group", style: .default, handler: {
            (action) in let enteredText = controller.textFields![0].text
            let groupDocRef = Firestore.firestore().document("groups/\(groupID)")
            let dataToSave: [String: Any] = ["title": enteredText!, "members": [userID], "iD": groupID, "trips": []]
            groupDocRef.setData(dataToSave) { (error) in
                if let error = error {
                    print("\(error.localizedDescription)")
                }
            }
            let userDocRef = Firestore.firestore().document("users/\(userID)")
            
            // New group is appended to user's groups field
            userDocRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    userDocRef.updateData([
                        "groups": FieldValue.arrayUnion(["\(groupID)"])
                    ])
                }
            }
        } ))
        present(controller, animated: true)
    }
    
    // MARK: - Navigation
    
    // Segue to SettingsVC
    @IBAction func settingsIconClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "toSettingsVC", sender: nil)
    }
    
    // Log out the user
    @IBAction func lohOutButtonClicked(_ sender: Any) {
        do {
            try Auth.auth().signOut()
            performSegue(withIdentifier: "signOutSegue", sender: self)
            userID = ""
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError.localizedDescription)")
        }
    }
    
    // Refresh button to reload the view
    @IBAction func refreshButton(_ sender: Any) {
        self.loadView()
        if darkMode {
            overrideUserInterfaceStyle = .dark
        }
        self.counter = 0
        let maxY1 = self.joinExistingGroupButton.frame.maxY
        let minY2 = self.createNewGroupButton.frame.minY
        let maxY2 = self.createNewGroupButton.frame.maxY + 10
        let minX = self.joinExistingGroupButton.frame.minX
        let height = self.joinExistingGroupButton.frame.height
        let width = self.joinExistingGroupButton.frame.width
        let spacing = minY2 - maxY1
        
        let userDocRef = Firestore.firestore().document("users/\(userID)")
        userDocRef.getDocument { (document, error) in
            if let document = document, document.exists {
                self.groups = document.get(String("groups")) as! Array<String>
                for group in self.groups {
                    self.counter = self.counter + 1
                    let myButton = UIButton(type: .system)
                    
                    // Position Button
                    let mySpace = self.counter * spacing
                    let buttonSpace = (self.counter) * height
                    print (self.counter)
                    
                    myButton.frame = CGRect(x: minX, y: maxY2 + mySpace + buttonSpace, width: width, height: height)
                    myButton.layer.cornerRadius = height / 4
                    myButton.titleLabel!.font = UIFont.systemFont(ofSize: 17.0, weight: UIFont.Weight.regular)
                    myButton.tag = Int(self.counter) - 1
                    
                    // Set text on button
                    let groupDocRef = Firestore.firestore().document("groups/\(group)")
                    groupDocRef.getDocument { (document, error) in
                        if let document = document, document.exists {
                            self.groupTitle = document.get(String("title")) as! String
                            myButton.setTitle("\(self.groupTitle)", for: .normal)
                            myButton.titleLabel?.tintColor = myDG
                            myButton.backgroundColor = mySLG
                            
                            // Set button action
                            myButton.addTarget(self, action: #selector(self.buttonAction(_:)), for: .touchUpInside)
                            
                            self.view.addSubview(myButton)
                            self.view = self.view
                        }
                    }
                }
            }
        }
    }
}

import UIKit
import FirebaseStorage
import FirebaseFirestore

class GroupInfoViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Outlets
    
    @IBOutlet weak var groupNameDisplay: UILabel!
    @IBOutlet weak var groupJoinCodeDisplay: UILabel!
    @IBOutlet weak var deleteGroupOutlet: UIButton!
    @IBOutlet weak var memberTable: UITableView!
    
    // MARK: - Properties
    
    let groupID = groupStack.peek()
    var members: [String] = []
    var memberNames: [String] = []
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check and apply dark mode
        if darkMode == true {
            overrideUserInterfaceStyle = .dark
        }
        
        memberTable.dataSource = self
        memberTable.delegate = self
    }
    
    // Formats the View and adds Relevant Group Information
    override func viewWillAppear(_ animated: Bool) {
        groupJoinCodeDisplay.layer.masksToBounds = true
        groupJoinCodeDisplay.layer.cornerRadius = groupJoinCodeDisplay.frame.height / 2.00
        groupJoinCodeDisplay.text = groupID
        
        groupDocRef = Firestore.firestore().document("groups/\(groupID)")
        groupDocRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let groupName = document.get(String("title")) as! String
                self.members = document.get(String("members")) as! Array<String>
                
                DispatchQueue.main.async {
                    self.groupNameDisplay.text = groupName
                    
                    DispatchQueue.main.async {
                        if self.members[0] == userID {
                            self.deleteGroupOutlet.isHidden = false
                        } else {
                            self.deleteGroupOutlet.isHidden = true
                        }
                        
                        // Clear existing memberNames before fetching new names
                        self.memberNames.removeAll()
                        
                        // Fetch member names
                        self.fetchMemberNames()
                    }
                }
            }
        }
    }
    
    // MARK: - TableView DataSource and Delegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.members.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "memberCell", for: indexPath)
        
        // Check if the index is within the bounds of memberNames
        guard indexPath.row < self.memberNames.count else {
            // If not, return an empty cell or handle it accordingly
            return cell
        }
        
        // Use the new content configuration to set the cell text
        var content = cell.defaultContentConfiguration()
        content.text = self.memberNames[indexPath.row]
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 42
    }
    
    // MARK: - Helper Functions
    
    // Fetch member names asynchronously
    func fetchMemberNames() {
        // Create a Dispatch Group
        let group = DispatchGroup()

        // Fetch user data for each member and update memberNames
        for member in self.members {
            group.enter() // Enter the Dispatch Group

            userDocRef = Firestore.firestore().document("users/\(member)")
            userDocRef.getDocument { (document, error) in
                defer {
                    group.leave() // Leave the Dispatch Group, even in case of an error
                }

                if let document = document, document.exists {
                    let name = document.get(String("name")) as! String
                    self.memberNames.append(name)
                }
            }
        }

        // Notify when all requests are completed
        group.notify(queue: .main) {
            // Reload the table view once all data is available
            self.memberTable.reloadData()
        }
    }
    
    // MARK: - Button Actions
    
    @IBAction func editGroupNameButtonClicked(_ sender: Any) {
        let controller = UIAlertController(
            title: "Change Group Name",
            message: "What would you like to rename the group?",
            preferredStyle: .alert)
        
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        controller.addTextField(configurationHandler: {
            (textField) in textField.placeholder = "Enter Group Name"
        } )
        
        // Actual group creation
        controller.addAction(UIAlertAction(title: "Rename Group", style: .default, handler: {
            (action) in
            let enteredText = controller.textFields![0].text
            if enteredText != "" {
                let groupDocRef = Firestore.firestore().document("groups/\(self.groupID)")
                groupDocRef.getDocument { (document, error) in
                    if let document = document, document.exists {
                        groupDocRef.updateData([
                            "title": String(enteredText!)
                        ])
                    }
                }
            }
        }))
        present(controller, animated: true)
    }
    
    @IBAction func settingsIconClicked(_ sender: Any) {
        groupStack.pop()
        performSegue(withIdentifier: "groupInfoToSettingsVC", sender: self)
    }
    
    // Returns to the main ViewController and pops the groupStack since it is no longer accessing that group's information
    @IBAction func returnButton(_ sender: Any) {
        groupStack.pop()
        performSegue(withIdentifier: "groupInfoToMainVC", sender: self)
    }
    
    @IBAction func deleteGroupButtonClicked(_ sender: Any){
        let group = DispatchGroup()
        
        // Function to delete items
        func deleteItems(groupID: String, trip: String, items: [String]) {
            for item in items {
                let itemDocRef = Firestore.firestore().document("groups/\(groupID)/trips/\(trip)/items/\(item)")
                group.enter()
                itemDocRef.delete { error in
                    group.leave()
                }
            }
        }
        
        // Fetch and delete trips
        let groupDocRef = Firestore.firestore().document("groups/\(groupID)")
        group.enter()
        groupDocRef.getDocument { groupDocument, error in
            defer {
                group.leave()
            }
            
            guard let groupDocument = groupDocument, groupDocument.exists else {
                return
            }
            self.members = groupDocument.get(String("members")) as! Array<String>
            if let trips = groupDocument.get(String("trips")) as? [String], !trips.isEmpty {
                for trip in trips {
                    let tripDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(trip)")
                    group.enter()
                    
                    // Use a nested DispatchGroup for items deletion
                    let itemsGroup = DispatchGroup()
                    
                    tripDocRef.getDocument { tripDocument, error in
                        defer {
                            group.leave()
                        }
                        
                        guard let tripDocument = tripDocument, tripDocument.exists else {
                            return
                        }
                        
                        if let items = tripDocument.get(String("itemIDs")) as? [String], !items.isEmpty {
                            // Enter the nested group for items deletion
                            itemsGroup.enter()
                            deleteItems(groupID: self.groupID, trip: trip, items: items)
                            // Leave the nested group after items deletion
                            itemsGroup.leave()
                        }
                        
                        // Wait for items deletion to complete before deleting the trip
                        itemsGroup.notify(queue: .main) {
                            tripDocRef.delete()
                        }
                    }
                }
            }
        }
        
        // Wait for all asynchronous tasks to complete
        group.notify(queue: .main) {
            // Delete group from user's groups
            for member in self.members {
                let userDocRef = Firestore.firestore().document("users/\(member)")
                group.enter()
                userDocRef.getDocument { document, error in
                    defer {
                        group.leave()
                    }
                    
                    guard let document = document, document.exists else {
                        return
                    }
                    
                    var groups = document.get(String("groups")) as! [String]
                    groups.removeAll { value in
                        return value == self.groupID
                    }
                    userDocRef.updateData(["groups": groups])
                }
            }
            
            // Perform any segue or other actions after all deletions are complete
            group.notify(queue: .main) {
                // Delete the groupDocRef after all inner tasks have completed
                groupDocRef.delete()
            }
        }
            // Delete group from user's groups
        for member in self.members {
            let userDocRef = Firestore.firestore().document("users/\(member)")
            userDocRef.getDocument { document, error in
                guard let document = document, document.exists else {
                    return
                }
                var groups = document.get(String("groups")) as! [String]
                groups.removeAll { value in
                    return value == self.groupID
                }
                userDocRef.updateData(["groups": groups])
            }
        }
        groupStack.pop()
        performSegue(withIdentifier: "groupInfoToMainVC", sender: self)
    }
}

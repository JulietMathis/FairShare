import UIKit
import FirebaseFirestore

class DisplayGroceryRunViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, AlertShower, VoteAlertShower {
    
    // MARK: - Outlets
    
    @IBOutlet weak var groceryTable: UITableView!
    @IBOutlet weak var groceryTripNameLabel: UILabel!
    @IBOutlet weak var deleteTripButtonOutlet: UIButton!
    @IBOutlet weak var newGroceryButtonOutlet: UIButton!
    
    // MARK: - Properties
    
    let tripID = tripStack.peek()
    let groupID = groupStack.peek()
    var items: [String] = []
    var prices: [String] = []
    var tripName = "placeholder"
    var groceryIDs: [String] = []
    var voted = false
    var isOwner = false
    var isPublic = false
    var owner = ""
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check and apply dark mode
        if darkMode == true {
            overrideUserInterfaceStyle = .dark
        }
        
        groceryTable.delegate = self
        groceryTable.dataSource = self
        
        // Fetch data from Firestore
        tripDocRef = Firestore.firestore().document("groups/\(groupID)/trips/\(tripID)")
        tripDocRef.getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let document = document, document.exists {
                // Extract trip details
                self.tripName = document.get(String("name")) as! String
                self.items = document.get(String("items")) as? [String] ?? []
                self.prices = document.get(String("prices")) as? [String] ?? []
                self.owner = document.get(String("owner")) as! String
                
                // Update UI on the main thread
                DispatchQueue.main.async {
                    userDocRef = Firestore.firestore().document("users/\(self.owner)")
                    userDocRef.getDocument { [weak self] (document, error) in
                        guard let self = self else { return }
                        
                        if let document = document, document.exists {
                            // Check if the trip is public or if the user is the owner
                            self.isPublic = document.get(String("publicEditing")) as! Bool
                            
                            self.groceryTripNameLabel.text = self.tripName
                            self.groceryTable.reloadData()
                            if self.owner == userID {
                                self.isOwner = true
                            }
                            
                            // Show/hide buttons based on ownership and public status
                            if self.isOwner || self.isPublic {
                                self.newGroceryButtonOutlet.isHidden = false
                                self.deleteTripButtonOutlet.isHidden = false
                            } else {
                                self.newGroceryButtonOutlet.isHidden = true
                                self.deleteTripButtonOutlet.isHidden = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Reload data on the grocery table when the view appears
        DispatchQueue.main.async {
            self.groceryTable.reloadData()
        }
    }
    
    // MARK: - TableView DataSource Methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "groceryCell", for: indexPath) as! groceryCell
        let row = indexPath.row
        
        cell.delegate = self
        cell.otherDelegate = self
        cell.changeMyVoteButtonOutlet.isHidden = true
        cell.deleteButtonOutlet.isHidden = true
        cell.yesButtonOutlet.isHidden = false
        cell.noButtonOutlet.isHidden = false
        cell.questionLabel.text = "Will you use this?"
        
        let myTitle = items[row]
        let price = prices[row]
        
        cell.textLabel?.numberOfLines = 0
        cell.groceryTitleLabel.text = myTitle
        cell.groceryPriceLabel.text = "$\(price)"
        cell.cellTag = row
        
        cell.yesButtonOutlet.layer.masksToBounds = true
        cell.yesButtonOutlet.layer.cornerRadius = 8
        cell.noButtonOutlet.layer.masksToBounds = true
        cell.noButtonOutlet.layer.cornerRadius = 8
        
        // Capture necessary variables
        let currentGroupID = self.groupID
        let currentTripID = self.tripID
        let currentUserID = userID
        
        tripDocRef = Firestore.firestore().document("groups/\(currentGroupID)/trips/\(currentTripID)")
        tripDocRef.getDocument { (document, error) in
            if let document = document, document.exists {
                self.groceryIDs = document.get(String("itemIDs")) as? [String] ?? []
            }
            
            if row < self.groceryIDs.count {
                let currentItemID = self.groceryIDs[row]
                let itemDocRef = Firestore.firestore().document("groups/\(currentGroupID)/trips/\(currentTripID)/items/\(currentItemID)")
                itemDocRef.getDocument { (document, error) in
                    if let newDocument = document, newDocument.exists {
                        let votersList = newDocument.get(String("voters")) as? Array<String>
                        if votersList!.contains(currentUserID) {
                            self.voted = true
                            cell.yesButtonOutlet.isHidden = true
                            cell.noButtonOutlet.isHidden = true
                            cell.questionLabel.text = "You have already voted!"
                            cell.changeMyVoteButtonOutlet.isHidden = false
                            if self.isOwner || self.isPublic {
                                cell.deleteButtonOutlet.isHidden = false
                            } else {
                                cell.deleteButtonOutlet.isHidden = true
                            }
                        }
                    }
                }
            } else {
                print("Row out of bounds, problem with groceryCell class in data, the yes button specifically.")
            }
        }
        
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 130
    }
    
    // MARK: - Button Actions
    
    // Overview button clicked
    @IBAction func overviewButtonClicked(_ sender: Any) {
        // Perform segue to overviewVC
    }

    // Back arrow button clicked
    @IBAction func backArrowButtonClicked(_ sender: Any) {
        // Perform segue back to GroceryTripsVC and pop the tripStack
        performSegue(withIdentifier: "backToGroceryTripsVC", sender: self)
        tripStack.pop()
    }
    
    // Home button clicked
    @IBAction func homeButtonClicked(_ sender: Any) {
        // Pop both tripStack and groupStack, then segue to MainVC
        tripStack.pop()
        groupStack.pop()
        self.performSegue(withIdentifier: "displayGroceryVCToMainVC", sender: self)
    }
    
    // Profile button clicked
    @IBAction func profileButtonClicked(_ sender: Any) {
        // Pop both tripStack and groupStack, then segue to ProfileVC
        tripStack.pop()
        groupStack.pop()
        self.performSegue(withIdentifier: "displayGroceryVCToProfile", sender: self)
    }
    
    // Settings button clicked
    @IBAction func settingsButtonClicked(_ sender: Any) {
        // Pop both tripStack and groupStack, then segue to SettingsVC
        tripStack.pop()
        groupStack.pop()
        self.performSegue(withIdentifier: "displayGroceryVCToSettings", sender: self)
    }
    
    // Delete trip button clicked
    @IBAction func deleteTripButtonClicked(_ sender: Any) {
        groupDocRef = Firestore.firestore().document("groups/\(groupID)")
        groupDocRef.getDocument { [weak self] (groupDocument, error) in
            guard let self = self else { return }
            if let groupDocument = groupDocument, groupDocument.exists {
                var trips = groupDocument.get(String("trips")) as? Array<String>
                if trips!.contains(tripID) {
                    trips!.removeAll { value in
                        return value == self.tripID
                    }
                    groupDocRef.updateData([
                        "trips": trips!
                    ])
                }
            }
        }
        tripDocRef = Firestore.firestore().document("groups/\(groupID)/trips/\(tripID)")
        tripDocRef.getDocument { [weak self] (tripDocument, error) in
            guard let self = self else { return }
            if let tripDocument = tripDocument, tripDocument.exists {
                tripDocRef.delete()
            }
        }
        //then segue back to groceryTripsVC
        tripStack.pop()
        self.performSegue(withIdentifier: "backToGroceryTripsVC", sender: self)
    }

    
    // MARK: - Alert Methods
    
    // Show alert for deleting an item
    func showAlert(sender: groceryCell) {
        let controller = UIAlertController(
            title: "Delete Item",
            message: "Are you sure you want to delete this item?",
            preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {
            (action) in
            return
        })
        controller.addAction(cancelAction)

        let destroyAction = UIAlertAction(title: "Delete", style: .destructive, handler: {
            (action) in
            // delete item
            var tempID = ""
            //var tempItem = ""
            var tempPrice = ""
            var tempPriceWTax = 0.00
            var tempTotalPrice = 0.00
            var newTotalPrice = 0.00
            var tempIDs: [String] = []
            var tempItems: [String] = []
            var tempPrices: [String] = []

            tripDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(self.tripID)")
            tripDocRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    tempIDs = document.get(String("itemIDs")) as? [String] ?? []
                    tempItems = document.get(String("items")) as? [String] ?? []
                    tempPrices = document.get(String("prices")) as? [String] ?? []
                    tempID = tempIDs[sender.cellTag]
                    tempPrice = tempPrices[sender.cellTag]
                    tempPriceWTax = Double(tempPrice)! * 1.0825
                    tempTotalPrice = (document.get(String("totalPrice")) as? Double)!
                    newTotalPrice = tempTotalPrice - tempPriceWTax

                    guard sender.cellTag < tempIDs.count else {
                        print("Row out of bounds, problem with groceryCell class in data, the yes button specifically.")
                        return
                    }

                    // Remove the item at the specified index
                    tempIDs.remove(at: sender.cellTag)
                    tempItems.remove(at: sender.cellTag)
                    tempPrices.remove(at: sender.cellTag)

                    // Update Firestore with the new arrays
                    tripDocRef.updateData([
                        "itemIDs": tempIDs,
                        "items": tempItems,
                        "prices": tempPrices,
                        "totalPrice": newTotalPrice
                    ])

                    let itemDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(self.tripID)/items/\(tempID)")
                    itemDocRef.getDocument { (document, error) in
                        if let newDocument = document, newDocument.exists {
                            itemDocRef.delete()
                        }
                    }

                    DispatchQueue.main.async {
                        self.groceryTable.reloadData()
                    }
                }
            }
        })
        controller.addAction(destroyAction)

        present(controller, animated: true)
    }
    
    // Show alert for changing vote
    func showVoteAlert(sender: groceryCell) {
        let controller = UIAlertController(
            title: "Change Vote",
            message: "Will you use this item?",
            preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {
            (action) in
            return
        })
        controller.addAction(cancelAction)

        let noAction = UIAlertAction(title: "No", style: .default, handler: {
            (action) in
            //change users only

            tripDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(self.tripID)")
            tripDocRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    let tempIDs = document.get(String("itemIDs")) as? [String] ?? []
                    let tempID = tempIDs[sender.cellTag]
                    
                

                    let itemDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(self.tripID)/items/\(tempID)")
                    itemDocRef.getDocument { (document, error) in
                        if let newDocument = document, newDocument.exists {
                            let tempUsers = newDocument.get(String("users")) as? [String] ?? []
                            if tempUsers.contains(userID) {
                                itemDocRef.updateData([
                                    "users":  FieldValue.arrayRemove([userID])
                                ])
                            }
                        }
                    }
                }
            }
        })
        controller.addAction(noAction)
        
        let yesAction = UIAlertAction(title: "Yes", style: .default, handler: {
            (action) in
            //change users only

            tripDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(self.tripID)")
            tripDocRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    let tempIDs = document.get(String("itemIDs")) as? [String] ?? []
                    let tempID = tempIDs[sender.cellTag]
                    
                

                    let itemDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(self.tripID)/items/\(tempID)")
                    itemDocRef.getDocument { (document, error) in
                        if let newDocument = document, newDocument.exists {
                            let tempUsers = newDocument.get(String("users")) as? [String] ?? []
                            if tempUsers.contains(userID) == false {
                                itemDocRef.updateData([
                                    "users":  FieldValue.arrayUnion([userID])
                                ])
                            }
                        }
                    }
                }
            }
        })
        
        controller.addAction(yesAction)

        present(controller, animated: true)
    }
}

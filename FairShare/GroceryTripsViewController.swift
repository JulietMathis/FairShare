import UIKit
import FirebaseFirestore

class GroceryTripsViewController: UIViewController {

    // MARK: - Outlets
    
    @IBOutlet weak var tabBarOutlet: UITabBarItem!
    @IBOutlet weak var newGroceryTripButton: UIButton!
    
    // MARK: - Properties
    
    let groupID = groupStack.peek()
    var tripCounter = 0.0
    var trips: [String] = []
    var tripName = "CHANGE"
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check and apply dark mode
        if darkMode == true {
            overrideUserInterfaceStyle = .dark
        }
    }
    
    // Manually adds buttons for the group's grocery trips to access their information
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Check and apply dark mode
        if darkMode == true {
            overrideUserInterfaceStyle = .dark
        }
        
        let maxY = newGroceryTripButton.frame.maxY
        let minX = newGroceryTripButton.frame.minX
        let height = newGroceryTripButton.frame.height
        let width = newGroceryTripButton.frame.width
        let spacing = height * 0.5
        
        let groupDocRef = Firestore.firestore().document("groups/\(self.groupID)")
        
        groupDocRef.getDocument { (document, error)  in
            if let document = document, document.exists {
                self.trips = document.get(String("trips")) as! Array<String>
                
                for trip in self.trips {
                    self.tripCounter = self.tripCounter + 1
                    let myButton = UIButton(type: .system)
                    
                    // Position Button
                    let mySpace = self.tripCounter * spacing
                    let buttonSpace = (self.tripCounter) * height
                    
                    myButton.frame = CGRect(x: minX, y: maxY + mySpace + buttonSpace, width: width, height: height)
                    myButton.layer.cornerRadius = height / 4
                    myButton.titleLabel!.font = UIFont.systemFont(ofSize: 17.0, weight: UIFont.Weight.regular)
                    myButton.tag = Int(self.tripCounter) - 1
                    
                    // Set text on button
                    tripDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(trip)")
                    tripDocRef.getDocument { (document, error) in
                        if let document = document, document.exists {
                            self.tripName = document.get(String("name")) as! String
                            myButton.setTitle("\(self.tripName)", for: .normal)
                            myButton.titleLabel?.tintColor = .darkGray
                            myButton.backgroundColor = .systemGray5
                            
                            // Set button action
                            myButton.addTarget(self, action: #selector(self.buttonAction(_:)), for: .touchUpInside)
                            
                            self.view.addSubview(myButton)
                            self.view = self.view
                        } else {
                            if let error = error {
                                print("Error: \(error.localizedDescription)")
                            } else {
                                print("Unknown error occurred.")
                            }
                        }
                    }
                }
            } else {
                print("error: \(error!.localizedDescription)")
            }
        }
    }
    
    // MARK: - Button Actions
    
    // Segues into DisplayGroceryTripVC with the information corresponding to said trip using the tag value and pushing the indexed trip ID onto tripStack
    @objc func buttonAction(_ sender:UIButton!) {
        let tag = sender.tag
        let tripCode = self.trips[tag]
        tripStack.push(String(tripCode))
        self.performSegue(withIdentifier: "toDisplayGroceryRunVC", sender: self)
    }
    
    // Creates a new grocery trip when "New Grocery Trip" is pressed.
    // It does this by presenting an alert controller where a user names the grocery trip, and then creating it in Firebase.
    @IBAction func newGroceryTripButtonPressed(_ sender: Any) {
        let tripID = Int.random(in: 1000000 ... 9999999)
        
        let controller = UIAlertController(
            title: "New Grocery Trip",
            message: "What would you like to name this trip?",
            preferredStyle: .alert)
        
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        controller.addTextField(configurationHandler: {
            (textField) in textField.placeholder = "Enter a Name for this Grocery Trip"
        } )
        
        controller.addAction(UIAlertAction(title: "Create Trip", style: .default, handler: {
            (action) in let enteredText = controller.textFields![0].text
            if enteredText != nil {
                
                //fetch number of groupmembers
                groupDocRef = Firestore.firestore().document("groups/\(self.groupID)")
                groupDocRef.getDocument { (document, error) in
                    if let document = document, document.exists {
                        let members = document.get(String("members")) as! Array<Any>
                        let membersInt = members.count
                        
                        //create a trip document for this trip
                        tripDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(tripID)")
                        let dataToSave: [String: Any] = ["iD": String(tripID), "name": enteredText!, "owner": userID, "items": [], "prices": [], "users": members, "itemIDs": [], "usersInt": membersInt, "totalPrice": 0]
                        tripDocRef.setData(dataToSave) { (error) in
                            if let error = error {
                                print("\(error.localizedDescription)")
                            }
                        }
                        
                        //update the trips field of the group's document by adding the new trip ID to the array
                        groupDocRef.getDocument { (document, error) in
                            if let document = document, document.exists {
                                groupDocRef.updateData([
                                    "trips": FieldValue.arrayUnion(["\(tripID)"])
                                ])
                            }
                        }
                    }
                }
            }
        } ))
        present(controller, animated: true)
    }
    
    // Settings icon clicked
    @IBAction func settingsIconClicked(_ sender: Any) {
        groupStack.pop()
        performSegue(withIdentifier: "groceryTripsToSettingsVC", sender: self)
    }
    
    // Return button clicked
    @IBAction func returnButtonClicked(_ sender: Any) {
        groupStack.pop()
        performSegue(withIdentifier: "groceryTripsToMainVC", sender: self)
    }
    
    // Refresh button clicked
    @IBAction func refreshButtonClicked(_ sender: Any) {
        self.loadView()
        if darkMode {
            overrideUserInterfaceStyle = .dark
        }
        self.tripCounter = 0
        let maxY = newGroceryTripButton.frame.maxY + 10
        let minX = newGroceryTripButton.frame.minX
        let height = newGroceryTripButton.frame.height
        let width = newGroceryTripButton.frame.width
        let spacing = height * 0.5
        
        let groupDocRef = Firestore.firestore().document("groups/\(self.groupID)")
        
        groupDocRef.getDocument { (document,error)  in
            if let document = document, document.exists {
                self.trips = document.get(String("trips")) as! Array<String>
                for trip in self.trips {
                    self.tripCounter = self.tripCounter + 1
                    let myButton = UIButton(type: .system)
                    
                    // Position Button
                    let mySpace = self.tripCounter * spacing
                    let buttonSpace = (self.tripCounter) * height
                    
                    myButton.frame = CGRect(x: minX, y: maxY + mySpace + buttonSpace, width: width, height: height)
                    myButton.layer.cornerRadius = height / 4
                    myButton.titleLabel!.font = UIFont.systemFont(ofSize: 17.0, weight: UIFont.Weight.regular)
                    myButton.tag = Int(self.tripCounter) - 1
                    
                    // Set text on button
                    tripDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(trip)")
                    tripDocRef.getDocument { (document, error) in
                        if let document = document, document.exists {
                            self.tripName = document.get(String("name")) as! String
                            myButton.setTitle("\(self.tripName)", for: .normal)
                            myButton.titleLabel?.tintColor = .darkGray
                            myButton.backgroundColor = .systemGray5
                            
                            // Set button action
                            myButton.addTarget(self, action: #selector(self.buttonAction(_:)), for: .touchUpInside)
                            
                            self.view.addSubview(myButton)
                            self.view = self.view
                        } else {
                            print("error: \(error!.localizedDescription)")
                        }
                    }
                }
            } else {
                print("error: \(error!.localizedDescription)")
            }
        }
    }
}

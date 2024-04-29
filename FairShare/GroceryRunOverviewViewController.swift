import UIKit
import FirebaseFirestore

class GroceryRunOverviewViewController: UIViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var titleOutlet: UILabel!
    @IBOutlet weak var totalPriceLabel: UILabel!
    @IBOutlet weak var totalItemsOutlet: UILabel!
    @IBOutlet weak var buyerOutlet: UILabel!
    @IBOutlet weak var myItemsOutlet: UILabel!
    @IBOutlet weak var myPriceOutlet: UILabel!
    @IBOutlet weak var progressOutlet: UILabel!
    @IBOutlet weak var statusLabelOutlet: UILabel!
    
    // MARK: - Properties
    
    let tripID = tripStack.peek()
    let groupID = groupStack.peek()
    var tripName = "placeholder"
    var tripUsers: [String] = []
    var itemIDs: [String] = []
    var prices: [String] = []
    var totalPrice = 0.00
    var itemNum = 0
    var buyer = ""
    var myItemNum = 0
    var myPrice = 0.00
    var progress = 0
    var prog = ""
    var voteCount = 0
    var statusBool = false
    var statusCounter = 0
    var isUserOwner = false
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check and apply dark mode
        if darkMode == true {
            overrideUserInterfaceStyle = .dark
        }
        
        // Apply styling to the status label
        self.statusLabelOutlet.layer.masksToBounds = true
        self.statusLabelOutlet.layer.cornerRadius = 8
        
        // Firestore document reference for the current trip
        tripDocRef = Firestore.firestore().document("groups/\(groupID)/trips/\(tripID)")
        tripDocRef.getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let document = document, document.exists {
                // Extract trip information from the Firestore document
                self.tripName = document.get(String("name")) as! String
                self.tripUsers = document.get(String("users")) as? [String] ?? []
                self.itemIDs = document.get(String("itemIDs")) as? [String] ?? []
                self.prices = document.get(String("prices")) as? [String] ?? []
                self.totalPrice = (document.get(String("totalPrice")) as? Double)!
                self.itemNum = self.itemIDs.count
                
                // Calculate progress based on the number of users and items
                if self.itemNum != 0 {
                    self.prog = self.format(double: Double(100) / Double(self.tripUsers.count * self.itemNum))
                } else {
                    self.prog = self.format(double: 0)
                }
                
                // Check if the current user is the owner of the trip
                let buyerID = document.get(String("owner")) as! String
                if userID == buyerID {
                    self.isUserOwner = true
                }
                
                // Get the buyer's name from Firestore
                userDocRef = Firestore.firestore().document("users/\(buyerID)")
                userDocRef.getDocument { [weak self] (document, error) in
                    guard let self = self else { return }
                    if let document = document, document.exists {
                        self.buyer = document.get(String("name")) as! String
                        
                        // Update the UI
                        self.updateUI()
                    }
                }

                // Use a dispatch group to wait for all asynchronous tasks to complete
                let dispatchGroup = DispatchGroup()

                // Iterate through each item in the trip
                for item in self.itemIDs {
                    dispatchGroup.enter()

                    // Firestore document reference for the current item
                    itemDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(self.tripID)/items/\(item)")
                    itemDocRef.getDocument { [weak self] (document, error) in
                        guard let self = self else { return }

                        if let newDocument = document, newDocument.exists {
                            // Update progress and calculate prices
                            let itemStatus = newDocument.get(String("done")) as? Bool
                            if itemStatus! {
                                self.statusCounter += 1
                            }

                            let itemUsers = newDocument.get(String("users")) as? [String] ?? []

                            if itemUsers.contains(userID) {
                                let itemUserCount = itemUsers.count
                                let itemPriceTax = newDocument.get(String("priceWTax")) as? Double
                                self.myItemNum += 1
                                self.myPrice += (itemPriceTax! / Double(itemUserCount))
                            }

                            let votes = newDocument.get(String("votes")) as! Int
                            if votes != 0 {
                                self.voteCount += votes
                            }
                        }

                        dispatchGroup.leave()
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    // This closure will be called when all asynchronous tasks are completed
                    self.updateUI()
                }
            }
        }
    }

    // MARK: - UI Update Method
    
    func updateUI() {
        DispatchQueue.main.async {
            self.titleOutlet.text = self.tripName
            self.totalPriceLabel.text = "$\(self.format(double: self.totalPrice))"
            self.totalItemsOutlet.text = String(self.itemNum)
            self.buyerOutlet.text = String(self.buyer)
            self.myItemsOutlet.text = String(self.myItemNum)
            self.myPriceOutlet.text = "$\(self.format(double: self.myPrice))"
            self.progressOutlet.text = "\(Int((Double(self.prog)! * Double(self.voteCount)).rounded()))%"
            
            // Check the status and update the status label accordingly
            if self.statusCounter == self.itemNum {
                if self.isUserOwner {
                    self.statusLabelOutlet.text = "You are owed $\(self.format(double: self.totalPrice - self.myPrice))"
                } else {
                    self.statusLabelOutlet.text = "You owe \(self.buyer) $\(self.format(double: self.myPrice))"
                }
            } else {
                self.statusLabelOutlet.text = "Finalized prices pending votes."
            }
        }
    }

    // MARK: - Button Actions
    
    @IBAction func backToGroceryRunButtonClicked(_ sender: Any) {
        tripStack.pop()
        groupStack.pop()
        self.performSegue(withIdentifier: "overviewBackToDisplayGroceryRunVC", sender: self)
    }

    @IBAction func settingsButtonClicked(_ sender: Any) {
        tripStack.pop()
        groupStack.pop()
        self.performSegue(withIdentifier: "groceryRunOverviewToSettingsVC", sender: self)
    }

    @IBAction func homeButtonClicked(_ sender: Any) {
        tripStack.pop()
        groupStack.pop()
        self.performSegue(withIdentifier: "groceryRunOverviewToMainVC", sender: self)
    }

    @IBAction func profileButtonClicked(_ sender: Any) {
        tripStack.pop()
        groupStack.pop()
        self.performSegue(withIdentifier: "groceryRunOverviewToProfile", sender: self)
    }

    // MARK: - Helper Method
    
    func format(double: Double) -> String {
        return String(format: "%.2f", double)
    }
}

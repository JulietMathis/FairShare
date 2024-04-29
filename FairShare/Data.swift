import Foundation
import UIKit
import FirebaseFirestore
import CoreData

// MARK: - Global Variables

// Global variable holding the userID, set in the login view controller when a user successfully logs in
var userID: String = ""

// MARK: - Stack Structure

struct Stack {
    private var items: [String] = []

    func peek() -> String {
        guard let topElement = items.first else { fatalError("This stack is empty.") }
        return topElement
    }

    mutating func pop() {
        return //items.removeFirst()
    }

    mutating func push(_ element: String) {
        items.insert(element, at: 0)
    }
}

// Public vars used to fetch the group/grocery trip currently being accessed
var groupStack =  Stack()
var tripStack = Stack()

// MARK: - Color Constants

let myG = UIColor(_colorLiteralRed: 102/255, green: 195/255, blue: 126/255, alpha: 1)
let myDG = UIColor(_colorLiteralRed: 63/255, green: 120/255, blue: 78/255, alpha: 1)
let myLG = UIColor(_colorLiteralRed: 159/255, green: 225/255, blue: 160/255, alpha: 1)
let mySLG = UIColor(_colorLiteralRed: 221/255, green: 246/255, blue: 221/255, alpha: 1)

// Firestore document references
var userDocRef: DocumentReference!
var groupDocRef: DocumentReference!
var tripDocRef: DocumentReference!
var itemDocRef: DocumentReference!

// Other global variables
var darkMode = false
var publicTripEditing = false

// MARK: - User Class

class User {
    var email: String
    var password: String
    var uid: String
    var name: String
    var phone: String
    var pfp: String
    var groups: Array<Any>
    
    
    init(initEmail: String, initPassword: String, initUID: String) {
        self.email = initEmail
        self.password = initPassword
        self.uid = initUID
        self.name = "Add your info"
        self.phone = "Add your info"
        self.pfp = "placeholder"
        self.groups = []
        
        
    }
    
    //This adds a user to Firebase
    func addToDB(uid: String){

        userDocRef = Firestore.firestore().document("users/\(uid)")
        //change name and phone here
        let docRef = Firestore.firestore().document("users/\(uid)")
        
        docRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let dataDescription = document.data().map(String.init(describing:)) ?? "nil"
                if document.get(String("name")) != nil {
                    self.name = document.get(String("name")) as! String
                    self.phone = document.get(String("phone")) as! String
                    self.pfp = document.get(String("pfp")) as! String
                    self.groups = document.get(String("groups")) as! Array
                    let dataToSave: [String: Any] = ["email": self.email, "password": self.password, "name": self.name, "phone": self.phone, "pfp": self.pfp, "groups": self.groups, "publicEditing": false]
                    docRef.setData(dataToSave) { (error) in
                        if let error = error {
                            print("\(error.localizedDescription)")
                        }
                    }
                }
            } else {
                let dataToSave: [String: Any] = ["email": self.email, "password": self.password, "name": self.name, "phone": self.phone, "pfp": self.pfp, "groups": self.groups]
                docRef.setData(dataToSave) { (error) in
                    if let error = error {
                        print("\(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// MARK: - Custom Cell for SettingsTableView

class settingsCell: UITableViewCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    @IBOutlet weak var settingLabel: UILabel!
    @IBOutlet weak var settingSwitch: UISwitch!
    
    //switches settings in CD when settings switches are switched
    @IBAction func settingSwitchSwitched(_ sender: Any) {
        let setting = self.settingLabel.text
        //print(setting)
        let fetchedSettings = retrieveSettings()
        if setting == "Dark Mode" {
            if fetchedSettings[0].value(forKey: "settingState") as! Bool == false {
                fetchedSettings[0].setValue(true, forKey: "settingState")
            } else if fetchedSettings[0].value(forKey: "settingState") as! Bool == true {
                fetchedSettings[0].setValue(false, forKey: "settingState")
            }
            saveContext()
            let fetchedSettings = retrieveSettings()
            darkMode = fetchedSettings[0].value(forKey: "settingState") as! Bool
            publicTripEditing = fetchedSettings[1].value(forKey: "settingState") as! Bool
            
        } else if setting == "Public Trip Editing" {
            if fetchedSettings[1].value(forKey: "settingState") as! Bool == false {
                fetchedSettings[1].setValue(true, forKey: "settingState")
            } else if fetchedSettings[1].value(forKey: "settingState") as! Bool == true {
                fetchedSettings[1].setValue(false, forKey: "settingState")
            }
            saveContext()
            let fetchedSettings = retrieveSettings()
            darkMode = fetchedSettings[0].value(forKey: "settingState") as! Bool
            publicTripEditing = fetchedSettings[1].value(forKey: "settingState") as! Bool
            
            //edit Firestore for public tripEditing
            userDocRef = Firestore.firestore().document("users/\(userID)")
            userDocRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    userDocRef.updateData([
                        "publicEditing": publicTripEditing
                    ])
                }
            }
        }
    }
}

// MARK: - Setting Object Class

class Setting {
    var name:String
    var state:Bool
    
    init(setName: String, setState: Bool) {
        self.name = setName
        self.state = setState
    }
}

// MARK: - Core Data Setup for Settings

let appDelegate = UIApplication.shared.delegate as! AppDelegate
let context = appDelegate.persistentContainer.viewContext

// MARK: - Core Data Functions for Settings

func retrieveSettings() -> [NSManagedObject] { //this isn't working, fix it
    
    let request = NSFetchRequest <NSFetchRequestResult>(entityName: "CDSetting")
    var fetchedSettings:[NSManagedObject]?
    do {
        try fetchedSettings = context.fetch(request) as? [NSManagedObject]
    } catch {
        print("Error occured while retrieving data")
        abort()
    }
    return (fetchedSettings)!
}

//Saves Context to Core Data if it has changed
func saveContext () {
    if context.hasChanges {
        do {
            try context.save()
        } catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
}

//Stores a Setting in the context
func storeSetting(name: String, state: Bool) {
    let setting = NSEntityDescription.insertNewObject(
        forEntityName: "CDSetting",
        into: context)
    setting.setValue(name, forKey: "settingName")
    setting.setValue(state, forKey: "settingState")
    saveContext()
}

//creates a Setting Object from SettingEntityObject
func makeSettingFromCD(from: NSManagedObject) -> Setting {
    var settingFromCD = Setting(setName: from.value(forKey: "settingName") as! String, setState: (from.value(forKey: "settingState") != nil))
    if let settingName = from.value(forKey: "settingName") {
        if let settingState = from.value(forKey: "settingState") {
            settingFromCD.name = (settingName as? String)!
            settingFromCD.state = (settingState as? Bool)!
            return settingFromCD
        }
        return settingFromCD
    }
    return settingFromCD
}

// MARK: - Custom Cell Class for GroceryTable

//custom cell class for groceryTable in DisplayGroceryRunViewController
class groceryCell: UITableViewCell {
    var delegate: AlertShower?
    var otherDelegate: VoteAlertShower?
    
    @IBOutlet weak var groceryTitleLabel: UILabel!
    @IBOutlet weak var groceryPriceLabel: UILabel!
    @IBOutlet weak var yesButtonOutlet: UIButton!
    @IBOutlet weak var noButtonOutlet: UIButton!
    @IBOutlet weak var questionLabel: UILabel!
    @IBOutlet weak var deleteButtonOutlet: UIButton!
    // make this hidden if non-owner
    @IBOutlet weak var changeMyVoteButtonOutlet: UIButton!
    
    var indexPathForCell: IndexPath?
    let groupID = groupStack.peek()
    let tripID = tripStack.peek()
    var groceryIDs: [String] = []
    var grocID = ""
    var cellTag: Int = 0
    
    var hasVoted: Bool = false // Local variable to track voting status for each cell
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    // yes button to vote you will use the grocery
    @IBAction func yesButton(_ sender: Any) {
        if !hasVoted { // Check if the user hasn't voted on this cell yet
            tripDocRef = Firestore.firestore().document("groups/\(groupID)/trips/\(tripID)")
            tripDocRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    self.groceryIDs = document.get(String("itemIDs")) as? [String] ?? []
                }
                
                if self.cellTag < self.groceryIDs.count {
                    let itemDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(self.tripID)/items/\(self.groceryIDs[self.cellTag])")
                    itemDocRef.getDocument { (document, error) in
                        if let newDocument = document, newDocument.exists {
                            let voteCheck = newDocument.get(String("votes")) as? Int
                            let targetVoteCheck = newDocument.get(String("targetVotes")) as? Int
                            //let usersCheck = document.get(String("users")) as? [String] ?? []
                            //possibly use this ^ to check that a person isn't double voting
                            if voteCheck == targetVoteCheck! - 1 {
                                itemDocRef.updateData([
                                    "users": FieldValue.arrayUnion([userID]),
                                    "voters": FieldValue.arrayUnion([userID]),
                                    "votes": voteCheck! + 1,
                                    "done": true
                                ]) { (error) in
                                    if let error = error {
                                        print("Error updating document: \(error)")
                                        return
                                    }
                                    
                                    DispatchQueue.main.async {
                                        // Update UI on the main thread
                                        self.yesButtonOutlet.isHidden = true
                                        self.noButtonOutlet.isHidden = true
                                        self.questionLabel.text = "You have already voted!"
                                        self.changeMyVoteButtonOutlet.isHidden = false
                                        self.hasVoted = true // Mark this cell as voted
                                    }
                                }
                            } else if voteCheck! < targetVoteCheck! - 1 {
                                itemDocRef.updateData([
                                    "users": FieldValue.arrayUnion([userID]),
                                    "voters": FieldValue.arrayUnion([userID]),
                                    "votes": voteCheck! + 1
                                ]) { (error) in
                                    if let error = error {
                                        print("Error updating document: \(error)")
                                        return
                                    }
                                    
                                    DispatchQueue.main.async {
                                        // Update UI on the main thread
                                        self.yesButtonOutlet.isHidden = true
                                        self.noButtonOutlet.isHidden = true
                                        self.questionLabel.text = "You have already voted!"
                                        self.changeMyVoteButtonOutlet.isHidden = false
                                        self.hasVoted = true // Mark this cell as voted
                                    }
                                }
                            } else if voteCheck! == targetVoteCheck! {
                                itemDocRef.updateData([
                                    "users": FieldValue.arrayUnion([userID]),
                                    "voters": FieldValue.arrayUnion([userID]),
                                    "votes": voteCheck! + 1,
                                    "targetVotes": targetVoteCheck! + 1,
                                    "done": true
                                ]) { (error) in
                                    if let error = error {
                                        print("Error updating document: \(error)")
                                        return
                                    }
                                    
                                    DispatchQueue.main.async {
                                        // Update UI on the main thread
                                        self.yesButtonOutlet.isHidden = true
                                        self.noButtonOutlet.isHidden = true
                                        self.questionLabel.text = "You have already voted!"
                                        self.changeMyVoteButtonOutlet.isHidden = false
                                        self.hasVoted = true // Mark this cell as voted
                                    }
                                }
                            }
                        }
                    }
                } else {
                    print("Row out of bounds, problem with groceryCell class in data, the yes button specifically.")
                }
            }
        }
    }
    
    // no button to vote you won't use the grocery
    @IBAction func noButton(_ sender: Any) {
        if !hasVoted { // Check if the user hasn't voted on this cell yet
            tripDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(tripID)")
            tripDocRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    self.groceryIDs = document.get(String("itemIDs")) as? [String] ?? []
                }
                
                if self.cellTag < self.groceryIDs.count {
                    let itemDocRef = Firestore.firestore().document("groups/\(self.groupID)/trips/\(self.tripID)/items/\(self.groceryIDs[self.cellTag])")
                    itemDocRef.getDocument { (document, error) in
                        if let newDocument = document, newDocument.exists {
                            let voteCheck = newDocument.get(String("votes")) as? Int
                            let targetVoteCheck = newDocument.get(String("targetVotes")) as? Int
                            //let usersCheck = document.get(String("users")) as? [String] ?? []
                            //possibly use this ^ to check that a person isn't double voting
                            if voteCheck == targetVoteCheck! - 1 {
                                itemDocRef.updateData([
                                    "voters": FieldValue.arrayUnion([userID]),
                                    "votes": voteCheck! + 1,
                                    "done": true
                                ]) { (error) in
                                    if let error = error {
                                        print("Error updating document: \(error)")
                                        return
                                    }
                                    
                                    DispatchQueue.main.async {
                                        // Update UI on the main thread
                                        self.yesButtonOutlet.isHidden = true
                                        self.noButtonOutlet.isHidden = true
                                        self.questionLabel.text = "You have already voted!"
                                        self.changeMyVoteButtonOutlet.isHidden = false
                                        self.hasVoted = true // Mark this cell as voted
                                    }
                                }
                            } else {
                                itemDocRef.updateData([
                                    "voters": FieldValue.arrayUnion([userID]),
                                    "votes": voteCheck! + 1
                                ]) { (error) in
                                    if let error = error {
                                        print("Error updating document: \(error)")
                                        return
                                    }
                                    
                                    DispatchQueue.main.async {
                                        // Update UI on the main thread
                                        self.yesButtonOutlet.isHidden = true
                                        self.noButtonOutlet.isHidden = true
                                        self.questionLabel.text = "You have already voted!"
                                        self.changeMyVoteButtonOutlet.isHidden = false
                                        self.hasVoted = true // Mark this cell as voted
                                    }
                                }
                            }
                        }
                    }
                } else {
                    print("Row out of bounds, problem with groceryCell class in data, the yes button specifically.")
                }
            }
        }
    }
    
    @IBAction func deleteButtonClicked(_ sender: Any) {
        self.delegate?.showAlert(sender: self)
    }
    
    @IBAction func changeMyVoteButtonClicked(_ sender: Any) {
        self.otherDelegate?.showVoteAlert(sender: self)
    }
}



// MARK: - Protocols for Showing Alerts

protocol AlertShower {
    func showAlert(sender: groceryCell)
}

protocol VoteAlertShower {
    func showVoteAlert(sender: groceryCell)
}

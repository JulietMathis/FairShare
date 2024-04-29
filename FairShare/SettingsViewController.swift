import UIKit

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Outlets
    
    @IBOutlet weak var settingsTable: UITableView!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up table view delegate and data source
        settingsTable.delegate = self
        settingsTable.dataSource = self
        
        // Check and apply dark mode
        if darkMode == true {
            overrideUserInterfaceStyle = .dark
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Reload table data when the view appears
        settingsTable.reloadData()
    }
    
    // MARK: - Table View Data Source
    
    // Define the number of rows in the section based on the settings fetched from Core Data
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let fetchedSettings = retrieveSettings()
        return fetchedSettings.count
    }
    
    // Configure and return each cell in the table view
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let fetchedSettings = retrieveSettings()
        let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath) as! settingsCell
        let row = indexPath.row
        
        // Set the label text and switch state based on fetched data
        cell.textLabel?.numberOfLines = 0
        cell.settingLabel.text = makeSettingFromCD(from: fetchedSettings[row]).name
        cell.settingSwitch.isOn = makeSettingFromCD(from: fetchedSettings[row]).state
        
        return cell
    }
    
    // Define the height of each table cell
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
}

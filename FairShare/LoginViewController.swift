import UIKit
import FirebaseAuth
import FirebaseFirestore

class LoginViewController: UIViewController, UITextFieldDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var confirmField: UITextField!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var signUpInstead: UIButton!
    @IBOutlet weak var SignInInstead: UIButton!
    @IBOutlet weak var needSignUpLabel: UILabel!
    @IBOutlet weak var needSignInLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    @IBOutlet weak var subView: UIView!
    
    // MARK: - Properties
    
    var docRef: DocumentReference!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        observeAuthenticationState()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        setupSettings()
    }
    
    // MARK: - UI Setup
    
    func setupUI() {
        emailField.delegate = self
        passwordField.delegate = self
        confirmField.delegate = self
        subView.layer.cornerRadius = 12
        configureLoginView()
        do {
            try Auth.auth().signOut()
            self.dismiss(animated: true)
        } catch {
            print("Sign out error")
        }
    }
    
    func configureLoginView() {
        titleLabel.text = "Login"
        confirmField.isHidden = true
        signUpButton.isHidden = true
        signInButton.isHidden = false
        needSignInLabel.isHidden = true
        SignInInstead.isHidden = true
        needSignUpLabel.isHidden = false
        signUpInstead.isHidden = false
        passwordField.isSecureTextEntry = true
        confirmField.isSecureTextEntry = true
    }
    
    // MARK: - Authentication Observation
    
    func observeAuthenticationState() {
        Auth.auth().addStateDidChangeListener() { (auth, user) in
            if user != nil {
                self.handleSuccessfulLogin()
            }
        }
    }
    
    func handleSuccessfulLogin() {
        userID = Auth.auth().currentUser!.uid
        let newUser = User(initEmail: emailField.text!, initPassword: passwordField.text!, initUID: userID)
        newUser.addToDB(uid: userID)
        performSegue(withIdentifier: "toMainVC", sender: nil)
        clearTextFields()
    }
    
    // MARK: - Settings Setup
    
    func setupSettings() {
        let mySettings = retrieveSettings()
        if mySettings.isEmpty {
            storeSetting(name: "Dark Mode", state: false)
            storeSetting(name: "Public Trip Editing", state: false)
        } else {
            darkMode = mySettings[0].value(forKey: "settingState") as! Bool
        }
        applyDarkModeSetting()
    }
    
    func applyDarkModeSetting() {
        if darkMode == true {
            overrideUserInterfaceStyle = .dark
        }
    }
    
    // MARK: - User Interaction
    
    @IBAction func signingIn(_ sender: Any) {
        signIn()
    }
    
    @IBAction func signingUp(_ sender: Any) {
        signUp()
    }
    
    @IBAction func switchToSignUp(_ sender: Any) {
        configureSignUpView()
    }
    
    @IBAction func switchToSignIn(_ sender: Any) {
        configureLoginView()
    }
    
    func signIn() {
        Auth.auth().signIn(withEmail: emailField.text!, password: passwordField.text!) { (authResult, error) in
            self.handleAuthenticationResult(error)
        }
    }
    
    func signUp() {
        if passwordField.text == confirmField.text {
            Auth.auth().createUser(withEmail: emailField.text!, password: passwordField.text!) { (authResult, error) in
                self.handleAuthenticationResult(error)
            }
            signIn()
        } else {
            statusLabel.text = "Password fields did not match."
        }
    }
    
    func handleAuthenticationResult(_ error: Error?) {
        if let error = error as NSError? {
            statusLabel.text = "\(error.localizedDescription)"
        } else {
            statusLabel.text = ""
        }
    }
    
    // MARK: - UI Configuration
    
    func configureSignUpView() {
        titleLabel.text = "Sign Up"
        signUpButton.isHidden = false
        confirmField.isHidden = false
        needSignInLabel.isHidden = false
        SignInInstead.isHidden = false
        needSignUpLabel.isHidden = true
        signUpInstead.isHidden = true
        signInButton.isHidden = true
    }
    
    func clearTextFields() {
        emailField.text = nil
        passwordField.text = nil
        confirmField.text = nil
    }
    
    // MARK: - Keyboard Handling
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}

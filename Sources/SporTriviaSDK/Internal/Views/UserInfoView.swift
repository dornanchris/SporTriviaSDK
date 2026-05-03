import SwiftUI

/// User info collection screen — first step in the custom game flow.
struct UserInfoView: View {
    @ObservedObject var gameState: GameState
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var saveMyInfo: Bool = false

    private let defaults = UserDefaults(suiteName: "com.sportrivia.sdk")

    private var theme: SporTriviaTheme { SporTriviaSDK.theme }

    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !phoneNumber.isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text("Player Information")
                        .font(.title2.bold())
                        .foregroundColor(theme.textColor)
                        .padding(.top, 40)

                    Group {
                        TextField("First Name", text: $firstName)
                        TextField("Last Name", text: $lastName)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                        TextField("Phone Number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)

                    Toggle("Save my info", isOn: $saveMyInfo)
                        .foregroundColor(theme.textColor)
                        .padding(.horizontal)

                    Button(action: submitForm) {
                        Text("Submit")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isFormValid ? theme.primaryColor : Color.gray)
                            .cornerRadius(8)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal)

                    Button(action: onCancel) {
                        Text("Cancel")
                            .foregroundColor(theme.textColor.opacity(0.7))
                            .padding()
                    }
                }
                .padding()
            }
        }
        .onAppear(perform: loadSavedInfo)
    }

    private func submitForm() {
        gameState.firstName = firstName
        gameState.lastName = lastName
        gameState.email = email
        gameState.phoneNumber = phoneNumber

        if saveMyInfo {
            defaults?.set(true, forKey: "saveUserInfo")
            defaults?.set(firstName, forKey: "firstName")
            defaults?.set(lastName, forKey: "lastName")
            defaults?.set(email, forKey: "email")
            defaults?.set(phoneNumber, forKey: "phoneNumber")
        } else {
            defaults?.set(false, forKey: "saveUserInfo")
            defaults?.removeObject(forKey: "firstName")
            defaults?.removeObject(forKey: "lastName")
            defaults?.removeObject(forKey: "email")
            defaults?.removeObject(forKey: "phoneNumber")
        }

        onSubmit()
    }

    private func loadSavedInfo() {
        guard defaults?.bool(forKey: "saveUserInfo") == true else { return }
        firstName = defaults?.string(forKey: "firstName") ?? ""
        lastName = defaults?.string(forKey: "lastName") ?? ""
        email = defaults?.string(forKey: "email") ?? ""
        phoneNumber = defaults?.string(forKey: "phoneNumber") ?? ""
        saveMyInfo = true
    }
}

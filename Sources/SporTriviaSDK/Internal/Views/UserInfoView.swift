import SwiftUI

/// Player info collection screen shown after the answer key loads.
///
/// The fields displayed are driven by the question's Data Capture
/// configuration in the SporTrivia portal (`collect_fields` in the answer
/// key JSON): standard name/email/phone fields, an over-18 checkbox, and
/// any custom questions. Legacy answer keys without a configuration show
/// the original name/email/phone form.
struct UserInfoView: View {
    @ObservedObject var gameState: GameState
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var over18: Bool = false
    @State private var customAnswers: [String: String] = [:]
    @State private var saveMyInfo: Bool = false

    private let defaults = UserDefaults(suiteName: "com.sportrivia.sdk")

    private var theme: SporTriviaTheme { SporTriviaSDK.theme }

    private var collectFields: CollectFields { gameState.collectFields }

    private var isFormValid: Bool {
        if collectFields.name && (firstName.isEmpty || lastName.isEmpty) {
            return false
        }
        if collectFields.email && email.isEmpty {
            return false
        }
        if collectFields.phone && phoneNumber.isEmpty {
            return false
        }
        for question in collectFields.customQuestions where question.required {
            let answer = (customAnswers[question.id] ?? "").trimmingCharacters(in: .whitespaces)
            if answer.isEmpty {
                return false
            }
        }
        return true
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

                    if collectFields.name {
                        inputField(TextField("First Name", text: $firstName))
                        inputField(TextField("Last Name", text: $lastName))
                    }

                    if collectFields.email {
                        inputField(
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                        )
                    }

                    if collectFields.phone {
                        inputField(
                            TextField("Phone Number", text: $phoneNumber)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                        )
                    }

                    ForEach(collectFields.customQuestions) { question in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Text(question.label)
                                    .font(.subheadline.bold())
                                    .foregroundColor(theme.textColor)
                                if question.required {
                                    Text("*")
                                        .foregroundColor(theme.incorrectColor)
                                }
                            }
                            inputField(
                                TextField(
                                    question.placeholder.isEmpty ? question.label : question.placeholder,
                                    text: customAnswerBinding(for: question)
                                )
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if collectFields.over18 {
                        Toggle("I am over 18", isOn: $over18)
                            .foregroundColor(theme.textColor)
                            .padding(.horizontal)
                    }

                    if hasStandardFields {
                        Toggle("Save my info", isOn: $saveMyInfo)
                            .foregroundColor(theme.textColor)
                            .padding(.horizontal)
                    }

                    Button(action: submitForm) {
                        Text("Submit")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: isFormValid
                                                ? [theme.primaryColor, theme.primaryColor.opacity(0.75)]
                                                : [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
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

    private var hasStandardFields: Bool {
        collectFields.name || collectFields.email || collectFields.phone
    }

    private func inputField<Field: View>(_ field: Field) -> some View {
        field
            .foregroundColor(theme.textColor)
            .accentColor(theme.accentColor)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255).opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255).opacity(0.3), lineWidth: 1)
            )
    }

    private func customAnswerBinding(for question: CustomCollectionQuestion) -> Binding<String> {
        Binding(
            get: { customAnswers[question.id] ?? "" },
            set: { customAnswers[question.id] = $0 }
        )
    }

    private func submitForm() {
        gameState.firstName = collectFields.name ? firstName : ""
        gameState.lastName = collectFields.name ? lastName : ""
        gameState.email = collectFields.email ? email : ""
        gameState.phoneNumber = collectFields.phone ? phoneNumber : ""
        gameState.over18 = collectFields.over18 ? over18 : false

        // Keyed by question label so downstream consumers (portal contacts
        // view, CSV export) show the question text, not an internal id.
        var answersByLabel: [String: String] = [:]
        for question in collectFields.customQuestions {
            let answer = (customAnswers[question.id] ?? "").trimmingCharacters(in: .whitespaces)
            if !answer.isEmpty {
                answersByLabel[question.label] = answer
            }
        }
        gameState.customFieldAnswers = answersByLabel

        if saveMyInfo && hasStandardFields {
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

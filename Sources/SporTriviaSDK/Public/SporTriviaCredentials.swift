import Foundation

/// AWS credentials issued by the SporTrivia team to a licensed partner.
///
/// Partners get a unique accessKey/secretKey pair from SporTrivia with an
/// IAM policy that scopes their access to SDK-required S3 paths only.
/// If a partner's license is revoked, these credentials will stop working.
public struct SporTriviaCredentials {
    public let accessKey: String
    public let secretKey: String
    public let region: String
    public let sessionToken: String?

    public init(accessKey: String, secretKey: String, region: String = "us-east-2", sessionToken: String? = nil) {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.region = region
        self.sessionToken = sessionToken
    }

    /// Load credentials from a plist file in the app bundle.
    ///
    /// The plist must contain keys: `SporTriviaAccessKey`, `SporTriviaSecretKey`,
    /// and optionally `SporTriviaRegion`.
    public static func fromPlist(named name: String = "SporTrivia", bundle: Bundle = .main) throws -> SporTriviaCredentials {
        guard let url = bundle.url(forResource: name, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw SporTriviaCredentialsError.plistNotFound(name)
        }
        guard let accessKey = plist["SporTriviaAccessKey"] as? String, !accessKey.isEmpty else {
            throw SporTriviaCredentialsError.missingKey("SporTriviaAccessKey")
        }
        guard let secretKey = plist["SporTriviaSecretKey"] as? String, !secretKey.isEmpty else {
            throw SporTriviaCredentialsError.missingKey("SporTriviaSecretKey")
        }
        let region = (plist["SporTriviaRegion"] as? String) ?? "us-east-2"
        return SporTriviaCredentials(accessKey: accessKey, secretKey: secretKey, region: region)
    }
}

public enum SporTriviaCredentialsError: LocalizedError {
    case plistNotFound(String)
    case missingKey(String)

    public var errorDescription: String? {
        switch self {
        case .plistNotFound(let name):
            return "Could not find \(name).plist in app bundle. Add the SporTrivia credentials plist provided by the SporTrivia team."
        case .missingKey(let key):
            return "Missing required key '\(key)' in SporTrivia credentials plist."
        }
    }
}

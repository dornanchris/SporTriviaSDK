import Foundation

/// Default credential provider that generates presigned S3 URLs using partner-issued AWS credentials.
///
/// This is the recommended provider for licensed SDK partners. It signs requests
/// entirely on-device using AWS Signature Version 4 — no backend required.
///
/// Usage:
/// ```swift
/// let credentials = try SporTriviaCredentials.fromPlist()
/// let provider = DefaultCredentialProvider(credentials: credentials, bucketName: "sportrivia")
/// SporTriviaSDK.configure(SporTriviaConfiguration(credentialProvider: provider))
/// ```
public final class DefaultCredentialProvider: SporTriviaCredentialProvider {
    private let signer: SigV4Signer
    private let bucketName: String
    private let expirationSeconds: Int

    /// Create a credential provider using AWS credentials issued by SporTrivia.
    /// - Parameters:
    ///   - credentials: Partner-issued AWS credentials (from SporTriviaCredentials)
    ///   - bucketName: S3 bucket (default: "sportrivia")
    ///   - expirationSeconds: How long each presigned URL is valid (default: 5 minutes).
    ///     Shorter is more secure; longer tolerates slower networks better.
    public init(credentials: SporTriviaCredentials, bucketName: String = "sportrivia", expirationSeconds: Int = 300) {
        self.signer = SigV4Signer(
            accessKey: credentials.accessKey,
            secretKey: credentials.secretKey,
            region: credentials.region,
            sessionToken: credentials.sessionToken
        )
        self.bucketName = bucketName
        self.expirationSeconds = expirationSeconds
    }

    public func presignedGetURL(forKey key: String) async throws -> URL {
        guard let url = signer.presignedURL(method: "GET", bucket: bucketName, key: key, expiresInSeconds: expirationSeconds) else {
            throw DefaultCredentialProviderError.signingFailed(key: key)
        }
        return url
    }

    public func presignedPutURL(forKey key: String) async throws -> URL {
        guard let url = signer.presignedURL(method: "PUT", bucket: bucketName, key: key, expiresInSeconds: expirationSeconds) else {
            throw DefaultCredentialProviderError.signingFailed(key: key)
        }
        return url
    }
}

public enum DefaultCredentialProviderError: LocalizedError {
    case signingFailed(key: String)

    public var errorDescription: String? {
        switch self {
        case .signingFailed(let key):
            return "Failed to generate presigned URL for '\(key)'. Verify your credentials are valid and the key contains only safe characters."
        }
    }
}

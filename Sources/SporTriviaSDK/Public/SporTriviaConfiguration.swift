import SwiftUI

/// Configuration for initializing the SporTrivia SDK.
public struct SporTriviaConfiguration {
    /// The S3 bucket name where game data is stored.
    public let s3BucketName: String

    /// Provider that generates presigned S3 URLs for the SDK.
    public let credentialProvider: SporTriviaCredentialProvider

    /// Optional theme customization. Uses default SporTrivia colors if nil.
    public let theme: SporTriviaTheme?

    public init(
        s3BucketName: String = "sportrivia",
        credentialProvider: SporTriviaCredentialProvider,
        theme: SporTriviaTheme? = nil
    ) {
        self.s3BucketName = s3BucketName
        self.credentialProvider = credentialProvider
        self.theme = theme
    }

    /// Convenience initializer for licensed SDK partners.
    /// Creates a configuration using a `DefaultCredentialProvider` backed by
    /// AWS credentials issued by the SporTrivia team.
    public init(
        credentials: SporTriviaCredentials,
        s3BucketName: String = "sportrivia",
        theme: SporTriviaTheme? = nil
    ) {
        self.s3BucketName = s3BucketName
        self.credentialProvider = DefaultCredentialProvider(credentials: credentials, bucketName: s3BucketName)
        self.theme = theme
    }
}

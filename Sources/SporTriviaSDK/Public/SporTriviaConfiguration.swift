import SwiftUI

/// Configuration for initializing the SporTrivia SDK.
public struct SporTriviaConfiguration {
    /// The S3 bucket name where game data is stored.
    public let s3BucketName: String

    /// Provider that generates presigned S3 URLs for the SDK.
    public let credentialProvider: SporTriviaCredentialProvider

    /// Optional theme customization. Uses default SporTrivia colors if nil.
    public let theme: SporTriviaTheme?

    /// The partner id assigned by the SporTrivia team. Used to build the
    /// deep-link scheme (`sportrivia-<partnerId>`) and to claim games that
    /// were saved off on the SDK redirect page before install.
    public let partnerId: String?

    /// Base URL of the SporTrivia redirect service (e.g.
    /// `https://sportrivia-app.com`). Required only for deferred/post-install
    /// game claiming via ``SporTriviaSDK/claimPendingGame(completion:)``.
    public let redirectBaseURL: URL?

    public init(
        s3BucketName: String = "sportrivia",
        credentialProvider: SporTriviaCredentialProvider,
        theme: SporTriviaTheme? = nil,
        partnerId: String? = nil,
        redirectBaseURL: URL? = nil
    ) {
        self.s3BucketName = s3BucketName
        self.credentialProvider = credentialProvider
        self.theme = theme
        self.partnerId = partnerId
        self.redirectBaseURL = redirectBaseURL
    }

    /// Convenience initializer for licensed SDK partners.
    /// Creates a configuration using a `DefaultCredentialProvider` backed by
    /// AWS credentials issued by the SporTrivia team.
    public init(
        credentials: SporTriviaCredentials,
        s3BucketName: String = "sportrivia",
        theme: SporTriviaTheme? = nil,
        partnerId: String? = nil,
        redirectBaseURL: URL? = nil
    ) {
        self.s3BucketName = s3BucketName
        self.credentialProvider = DefaultCredentialProvider(credentials: credentials, bucketName: s3BucketName)
        self.theme = theme
        self.partnerId = partnerId
        self.redirectBaseURL = redirectBaseURL
    }
}

import Foundation

/// Protocol that host apps implement to provide S3 access.
///
/// The SDK never handles raw AWS credentials. Instead, the host app
/// generates presigned URLs using whatever auth mechanism it prefers
/// (Cognito, IAM role, backend proxy, etc.).
public protocol SporTriviaCredentialProvider: Sendable {
    /// Return a presigned GET URL for downloading the given S3 object key.
    /// Called on a background thread.
    func presignedGetURL(forKey key: String) async throws -> URL

    /// Return a presigned PUT URL for uploading to the given S3 object key.
    /// Called on a background thread.
    func presignedPutURL(forKey key: String) async throws -> URL
}

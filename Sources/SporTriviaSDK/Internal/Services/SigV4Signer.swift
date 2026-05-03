import Foundation
import CryptoKit

/// Generates AWS Signature Version 4 presigned URLs for S3.
///
/// Reference: https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html
///
/// This is a self-contained implementation — the SDK has no AWS SDK dependency.
/// Only HMAC-SHA256 and SHA-256 (from CryptoKit, iOS 13+) are used.
struct SigV4Signer {
    let accessKey: String
    let secretKey: String
    let region: String
    let sessionToken: String?
    let service = "s3"

    /// Create a presigned URL for an S3 object.
    /// - Parameters:
    ///   - method: HTTP method ("GET" or "PUT")
    ///   - bucket: S3 bucket name
    ///   - key: S3 object key (e.g., "answer_keys/custom/NYI_Top5A.json")
    ///   - expiresInSeconds: URL expiration (max 604800 = 7 days; default 300 = 5 minutes)
    /// - Returns: A presigned URL valid for the specified duration.
    func presignedURL(method: String, bucket: String, key: String, expiresInSeconds: Int = 300) -> URL? {
        let now = Date()
        let amzDate = SigV4Signer.amzDateFormatter.string(from: now)
        let dateStamp = SigV4Signer.dateStampFormatter.string(from: now)

        let host = "\(bucket).s3.\(region).amazonaws.com"
        let canonicalURI = "/" + key.split(separator: "/").map { uriEncode(String($0), encodeSlash: true) }.joined(separator: "/")
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"

        // Build canonical query string (must be sorted alphabetically by key)
        var queryParams: [(String, String)] = [
            ("X-Amz-Algorithm", "AWS4-HMAC-SHA256"),
            ("X-Amz-Credential", "\(accessKey)/\(credentialScope)"),
            ("X-Amz-Date", amzDate),
            ("X-Amz-Expires", String(expiresInSeconds)),
            ("X-Amz-SignedHeaders", "host"),
        ]
        if let token = sessionToken {
            queryParams.append(("X-Amz-Security-Token", token))
        }
        queryParams.sort { $0.0 < $1.0 }

        let canonicalQuery = queryParams
            .map { "\(uriEncode($0.0, encodeSlash: true))=\(uriEncode($0.1, encodeSlash: true))" }
            .joined(separator: "&")

        // Canonical request
        let canonicalHeaders = "host:\(host)\n"
        let signedHeaders = "host"
        let payloadHash = "UNSIGNED-PAYLOAD"
        let canonicalRequest = [
            method,
            canonicalURI,
            canonicalQuery,
            canonicalHeaders,
            signedHeaders,
            payloadHash,
        ].joined(separator: "\n")

        // String to sign
        let canonicalRequestHash = sha256Hex(canonicalRequest)
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            canonicalRequestHash,
        ].joined(separator: "\n")

        // Derive signing key
        let kDate = hmac(key: Array("AWS4\(secretKey)".utf8), data: Array(dateStamp.utf8))
        let kRegion = hmac(key: kDate, data: Array(region.utf8))
        let kService = hmac(key: kRegion, data: Array(service.utf8))
        let kSigning = hmac(key: kService, data: Array("aws4_request".utf8))

        // Compute signature
        let signature = hmac(key: kSigning, data: Array(stringToSign.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        // Final URL
        let finalQuery = canonicalQuery + "&X-Amz-Signature=\(signature)"
        return URL(string: "https://\(host)\(canonicalURI)?\(finalQuery)")
    }

    // MARK: - Helpers

    private func uriEncode(_ string: String, encodeSlash: Bool) -> String {
        var allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")
        if !encodeSlash {
            allowed.insert(charactersIn: "/")
        }
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private func sha256Hex(_ string: String) -> String {
        let hash = SHA256.hash(data: Data(string.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func hmac(key: [UInt8], data: [UInt8]) -> [UInt8] {
        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Array(mac)
    }

    private static let amzDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let dateStampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

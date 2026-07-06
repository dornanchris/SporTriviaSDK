import XCTest
@testable import SporTriviaSDK

final class S3DataServiceTests: XCTestCase {

    func testUploadGameResultsUsesResponsePath() async {
        let provider = KeyCapturingProvider()
        let service = S3DataService(credentialProvider: provider, bucketName: "test")

        _ = try? await service.uploadGameResults(
            responsePath: "custom/MLB/CD Test/who-holds-the-home-run-record/responses/",
            resultData: Data()
        )

        let key = provider.lastPutKey
        XCTAssertNotNil(key)
        XCTAssertTrue(key!.hasPrefix("custom/MLB/CD Test/who-holds-the-home-run-record/responses/"))
        XCTAssertFalse(key!.contains("//"), "trailing slash in response_path must not produce a double slash")
        XCTAssertTrue(key!.hasSuffix(".json"))
    }

    func testUploadGameResultsResponsePathWithoutTrailingSlash() async {
        let provider = KeyCapturingProvider()
        let service = S3DataService(credentialProvider: provider, bucketName: "test")

        _ = try? await service.uploadGameResults(
            responsePath: "custom/NHL/New York Islanders/some-question/responses",
            resultData: Data()
        )

        let key = provider.lastPutKey
        XCTAssertNotNil(key)
        XCTAssertTrue(key!.hasPrefix("custom/NHL/New York Islanders/some-question/responses/"))
        XCTAssertFalse(key!.contains("//"))
    }

    func testLegacyUploadGameResultsPathUnchanged() async {
        let provider = KeyCapturingProvider()
        let service = S3DataService(credentialProvider: provider, bucketName: "test")

        _ = try? await service.uploadGameResults(
            sport: .mlb,
            teamName: "New York Yankees",
            suffix: "NYM",
            resultData: Data()
        )

        let key = provider.lastPutKey
        XCTAssertNotNil(key)
        XCTAssertTrue(key!.hasPrefix("custom/MLB/New York Yankees/NYM/"))
        XCTAssertTrue(key!.hasSuffix(".json"))
    }
}

// MARK: - Mock

/// Records the key requested for a presigned PUT, then throws so the test
/// never performs a network request.
private final class KeyCapturingProvider: SporTriviaCredentialProvider, @unchecked Sendable {
    private(set) var lastPutKey: String?

    struct StopTest: Error {}

    func presignedGetURL(forKey key: String) async throws -> URL {
        throw StopTest()
    }

    func presignedPutURL(forKey key: String) async throws -> URL {
        lastPutKey = key
        throw StopTest()
    }
}

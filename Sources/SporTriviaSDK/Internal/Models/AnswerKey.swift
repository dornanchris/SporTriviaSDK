import Foundation

/// Represents a custom game answer key downloaded from S3.
struct AnswerKey: Decodable {
    let player_id: [String]
    let combo: String
    let type: Int
    let question: String?
    let collectFields: CollectFields?
    let sponsorship: SponsorshipInfo?
    /// S3 prefix where game results must be uploaded, embedded by the portal
    /// (e.g. "custom/MLB/CD Test/who-holds-the-home-run-record/responses/").
    /// Answer keys published before this field existed have none — the SDK
    /// falls back to deriving a path from the gameId.
    let responsePath: String?

    enum CodingKeys: String, CodingKey {
        case player_id
        case combo
        case type
        case question
        case collect_fields
        case sponsorship
        case response_path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle player_id as [String] or [Int]
        if let playerIds = try? container.decode([String].self, forKey: .player_id) {
            player_id = playerIds
        } else if let playerIds = try? container.decode([Int].self, forKey: .player_id) {
            player_id = playerIds.map { String($0) }
        } else {
            throw DecodingError.typeMismatch(
                [String].self,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Expected [String] or [Int] for player_id"
                )
            )
        }

        combo = try container.decode(String.self, forKey: .combo)
        type = try container.decode(Int.self, forKey: .type)
        question = try container.decodeIfPresent(String.self, forKey: .question)
        collectFields = try? container.decodeIfPresent(CollectFields.self, forKey: .collect_fields)
        sponsorship = try? container.decodeIfPresent(SponsorshipInfo.self, forKey: .sponsorship)
        responsePath = (try? container.decodeIfPresent(String.self, forKey: .response_path)) ?? nil
    }
}

/// Per-question sponsorship chosen in the SporTrivia portal and embedded
/// in the answer key JSON. `assetKey` is the S3 key of the banner image.
struct SponsorshipInfo: Decodable, Equatable {
    let brand: String
    let url: String
    let assetKey: String

    enum CodingKeys: String, CodingKey {
        case brand
        case url
        case asset_key
    }

    init(brand: String, url: String, assetKey: String) {
        self.brand = brand
        self.url = url
        self.assetKey = assetKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        brand = (try? container.decodeIfPresent(String.self, forKey: .brand)) ?? ""
        url = (try? container.decodeIfPresent(String.self, forKey: .url)) ?? ""
        assetKey = (try? container.decodeIfPresent(String.self, forKey: .asset_key)) ?? ""
    }
}

/// Data-capture configuration embedded in the answer key by the SporTrivia
/// portal (the question's Data Capture step). Drives which fields the
/// player-info screen shows and which answers are uploaded with results.
struct CollectFields: Decodable, Equatable {
    let name: Bool
    let email: Bool
    let phone: Bool
    let over18: Bool
    let customQuestions: [CustomCollectionQuestion]

    enum CodingKeys: String, CodingKey {
        case name
        case email
        case phone
        case over_18
        case custom_questions
    }

    init(name: Bool, email: Bool, phone: Bool, over18: Bool, customQuestions: [CustomCollectionQuestion]) {
        self.name = name
        self.email = email
        self.phone = phone
        self.over18 = over18
        self.customQuestions = customQuestions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decodeIfPresent(Bool.self, forKey: .name)) ?? false
        email = (try? container.decodeIfPresent(Bool.self, forKey: .email)) ?? false
        phone = (try? container.decodeIfPresent(Bool.self, forKey: .phone)) ?? false
        over18 = (try? container.decodeIfPresent(Bool.self, forKey: .over_18)) ?? false
        customQuestions = (try? container.decodeIfPresent([CustomCollectionQuestion].self, forKey: .custom_questions)) ?? []
    }

    /// Answer keys written before data capture existed have no
    /// collect_fields — keep the original all-fields behavior for them.
    static let legacyDefault = CollectFields(name: true, email: true, phone: true, over18: false, customQuestions: [])

    var hasAnythingToCollect: Bool {
        name || email || phone || over18 || !customQuestions.isEmpty
    }
}

/// A custom data-collection question configured in the portal.
struct CustomCollectionQuestion: Decodable, Equatable, Identifiable {
    let id: String
    let label: String
    let placeholder: String
    let required: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case placeholder
        case required
    }

    init(id: String, label: String, placeholder: String, required: Bool) {
        self.id = id
        self.label = label
        self.placeholder = placeholder
        self.required = required
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = (try? container.decodeIfPresent(String.self, forKey: .label)) ?? ""
        let rawId = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
        id = rawId.isEmpty ? label : rawId
        placeholder = (try? container.decodeIfPresent(String.self, forKey: .placeholder)) ?? ""
        required = (try? container.decodeIfPresent(Bool.self, forKey: .required)) ?? false
    }
}

// Player lists (all_{sport}_players.json) are parsed with JSONSerialization in
// JsonParser.parsePlayerList (mirroring the Android SDK), not Codable — see
// that method for the tolerant field handling.

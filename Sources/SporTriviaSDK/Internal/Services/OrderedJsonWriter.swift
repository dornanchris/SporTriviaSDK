import Foundation

/// A JSON value that serializes object keys in the exact order given.
///
/// `JSONSerialization` builds objects from unordered dictionaries (and its
/// `.sortedKeys` option is alphabetical only), so it cannot produce the
/// stable, documented field order the game-result schema guarantees to
/// partners. This tiny writer emits RFC 8259-compliant JSON with objects
/// as ordered key/value pair arrays instead.
indirect enum JsonValue {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JsonValue])
    case object([(String, JsonValue)])

    /// Serialize to compact JSON.
    func serialized() -> String {
        switch self {
        case .string(let value):
            return JsonValue.escape(value)
        case .int(let value):
            return String(value)
        case .double(let value):
            // JSON forbids NaN/Infinity; a fix with a broken coordinate is
            // worthless anyway, so emit null rather than invalid JSON.
            guard value.isFinite else { return "null" }
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return "null"
        case .array(let items):
            return "[" + items.map { $0.serialized() }.joined(separator: ",") + "]"
        case .object(let pairs):
            let body = pairs
                .map { "\(JsonValue.escape($0.0)):\($0.1.serialized())" }
                .joined(separator: ",")
            return "{" + body + "}"
        }
    }

    func serializedData() -> Data {
        Data(serialized().utf8)
    }

    private static func escape(_ string: String) -> String {
        var out = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}

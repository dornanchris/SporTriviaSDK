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
    /// Serialize to JSON.
    /// - Parameters:
    ///   - pretty: when true, one field per line, 2-space indented, nested
    ///     objects/arrays expanded (empty ones stay inline). Key order and
    ///     content are identical to the compact form.
    ///   - indentLevel: internal recursion depth; callers pass 0.
    func serialized(pretty: Bool = false, indentLevel: Int = 0) -> String {
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
            if items.isEmpty { return "[]" }
            if !pretty {
                return "[" + items.map { $0.serialized() }.joined(separator: ",") + "]"
            }
            let inner = String(repeating: "  ", count: indentLevel + 1)
            let outer = String(repeating: "  ", count: indentLevel)
            let body = items
                .map { inner + $0.serialized(pretty: true, indentLevel: indentLevel + 1) }
                .joined(separator: ",\n")
            return "[\n" + body + "\n" + outer + "]"
        case .object(let pairs):
            if pairs.isEmpty { return "{}" }
            if !pretty {
                let body = pairs
                    .map { "\(JsonValue.escape($0.0)):\($0.1.serialized())" }
                    .joined(separator: ",")
                return "{" + body + "}"
            }
            let inner = String(repeating: "  ", count: indentLevel + 1)
            let outer = String(repeating: "  ", count: indentLevel)
            let body = pairs
                .map { "\(inner)\(JsonValue.escape($0.0)): \($0.1.serialized(pretty: true, indentLevel: indentLevel + 1))" }
                .joined(separator: ",\n")
            return "{\n" + body + "\n" + outer + "}"
        }
    }

    func serializedData(pretty: Bool = false) -> Data {
        Data(serialized(pretty: pretty).utf8)
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

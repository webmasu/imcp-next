import CoreLocation
import Foundation
import MCP

struct ToolInputError: LocalizedError, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
    var errorDescription: String? { description }
}

extension MCP.Value {
    var numericValue: Double? {
        switch self {
        case .int(let value): Double(value)
        case .double(let value) where value.isFinite: value
        default: nil
        }
    }
}

extension Dictionary where Key == String, Value == MCP.Value {
    func optionalText(_ key: String) throws -> String? {
        guard let value = self[key] else { return nil }
        guard let text = value.stringValue else { throw ToolInputError("\(key) must be a string.") }
        return text
    }

    func requiredText(_ key: String) throws -> String {
        guard let text = try optionalText(key), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolInputError("\(key) is required.")
        }
        return text
    }

    /// Accept the existing single-id form or an explicit, bounded batch.
    func selectedIDs() throws -> [String] {
        if self["ids"] == nil { return [try requiredText("id")] }
        guard self["id"] == nil, let values = self["ids"]?.arrayValue,
            (1 ... 500).contains(values.count)
        else {
            throw ToolInputError("Specify id or an array of 1 to 500 ids.")
        }
        var seen = Set<String>()
        var ids: [String] = []
        for value in values {
            guard let id = value.stringValue, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ToolInputError("Each id must be a nonempty string.")
            }
            if seen.insert(id).inserted { ids.append(id) }
        }
        return ids
    }

    func location(latitude: String = "latitude", longitude: String = "longitude") throws -> CLLocation {
        func number(_ key: String) throws -> Double {
            guard let value = self[key]?.numericValue else { throw ToolInputError("\(key) must be a number.") }
            return value
        }
        let coordinate = try CLLocationCoordinate2D(latitude: number(latitude), longitude: number(longitude))
        guard CLLocationCoordinate2DIsValid(coordinate) else { throw ToolInputError("Invalid coordinates.") }
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

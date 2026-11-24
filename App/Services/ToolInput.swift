import CoreLocation
import Foundation
import MCP

struct ToolInputError: LocalizedError, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
    var errorDescription: String? { description }
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

    func location(latitude: String = "latitude", longitude: String = "longitude") throws -> CLLocation {
        func number(_ key: String) throws -> Double {
            switch self[key] {
            case .double(let n): return n
            case .int(let n): return Double(n)
            default: throw ToolInputError("\(key) must be a number.")
            }
        }
        let coordinate = try CLLocationCoordinate2D(latitude: number(latitude), longitude: number(longitude))
        guard CLLocationCoordinate2DIsValid(coordinate) else { throw ToolInputError("Invalid coordinates.") }
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

import CoreLocation
import Foundation
import Ontology
import WeatherKit

extension WeatherService {
    static var historical: Tool {
        Tool(
            name: "weather_history",
            description: "Get daily weather for up to ten local calendar days, starting August 1, 2021.",
            inputSchema: .object(
                properties: [
                    "latitude": .number(), "longitude": .number(),
                    "startDate": .string(description: "First local day, YYYY-MM-DD."),
                    "endDate": .string(description: "Last local day, inclusive. Defaults to startDate."),
                ],
                required: ["latitude", "longitude", "startDate"],
                additionalProperties: false
            ),
            annotations: .init(title: "Historical Daily Weather", readOnlyHint: true, openWorldHint: true)
        ) { args in
            let location = try args.location()
            let start = try args.requiredText("startDate")
            let end = try args.optionalText("endDate") ?? start
            guard let zone = try await CLGeocoder().reverseGeocodeLocation(location).first?.timeZone else {
                throw ToolInputError("Could not resolve the time zone at the requested coordinates.")
            }
            let range = try Self.historyInterval(start: start, end: end, zone: zone)
            let days = try await WeatherKit.WeatherService.shared.weather(
                for: location,
                including: .daily(startDate: range.start, endDate: range.end)
            )
            var metadata = Self.attribution
            metadata["timeZone"] = .string(zone.identifier)
            let forecasts = days.filter { $0.date >= range.start && $0.date < range.end }.map { WeatherForecast($0) }
            let encoder = JSONEncoder()
            encoder.userInfo[Ontology.DateTime.timeZoneOverrideKey] = zone
            encoder.userInfo[JSONLD.omitsNestedTypesKey] = true
            let data = try encoder.encode(JSONLDGraph(forecasts, properties: metadata))
            return try JSONDecoder().decode(Value.self, from: data)
        }
    }

    static func historyInterval(start: String, end: String, zone: TimeZone, now: Date = .now) throws -> DateInterval {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        formatter.calendar = calendar
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let first = formatter.date(from: start), formatter.string(from: first) == start,
            let last = formatter.date(from: end), formatter.string(from: last) == end,
            start >= "2021-08-01", last >= first, last <= now,
            let count = calendar.dateComponents([.day], from: first, to: last).day, count < 10,
            let next = calendar.date(byAdding: .day, value: 1, to: last)
        else { throw ToolInputError("Expected 1 to 10 consecutive days from 2021-08-01 through today (YYYY-MM-DD).") }
        return DateInterval(start: first, end: next)
    }
}

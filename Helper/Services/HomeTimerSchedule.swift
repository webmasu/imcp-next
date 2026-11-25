import Foundation
import HomeKit

@MainActor
enum HomeTimerSchedule {
    static func futureDate(_ text: String) throws -> Date {
        guard let date = ISO8601DateFormatter().date(from: text) ?? ISO8601DateFormatter.fractional.date(from: text),
            date > Date(), date.timeIntervalSince1970.truncatingRemainder(dividingBy: 60) == 0
        else { throw HomeError("fire_at must be a future ISO 8601 timestamp on a whole minute.") }
        return date
    }

    static func update(_ trigger: HMTrigger, arguments args: HomeArguments) async throws -> Bool {
        let fields = ["time", "fire_at", "recurrence"].filter { args.input[$0] != nil }
        guard let field = fields.first else { return false }
        guard fields.count == 1, args.input["name"] == nil, args.input["enabled"] == nil else {
            throw HomeError("Submit one schedule change per call, then read back the automation.")
        }
        if let timer = trigger as? HMTimerTrigger {
            switch field {
            case "fire_at":
                try await timer.updateFireDate(futureDate(try args.required(field)))
            case "recurrence":
                switch try args.required(field) {
                case "once": try await timer.updateRecurrence(nil)
                case "daily": try await timer.updateRecurrence(DateComponents(day: 1))
                default: throw HomeError("A regular timer accepts daily or once.")
                }
            default: throw HomeError("Use fire_at to change the time of a timer.")
            }
            return true
        }
        guard let event = trigger as? HMEventTrigger, event.events.count == 1,
            let calendar = event.events.first as? HMCalendarEvent,
            calendar.fireDateComponents.hour != nil, calendar.fireDateComponents.minute != nil
        else { throw HomeError("This automation does not have a single calendar time trigger.") }
        switch field {
        case "time":
            let parts = try args.required(field).split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2, parts.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isNumber) }),
                let hour = Int(parts[0]), let minute = Int(parts[1]), (0 ..< 24).contains(hour),
                (0 ..< 60).contains(minute)
            else { throw HomeError("Use the 24-hour time format HH:mm.") }
            var components = calendar.fireDateComponents
            components.hour = hour
            components.minute = minute
            try await event.updateEvents([HMCalendarEvent(fire: components)])
        case "recurrence":
            let value = try args.value(field)
            if value.stringValue == "daily" {
                try await event.updateRecurrences(nil)
            } else if case .array(let values) = value, !values.isEmpty {
                let days = try values.map { value -> DateComponents in
                    guard case .int(let day) = value, (1 ... 7).contains(day) else {
                        throw HomeError("Invalid weekday.")
                    }
                    return DateComponents(weekday: day)
                }
                try await event.updateRecurrences(days)
            } else {
                throw HomeError("A calendar time trigger accepts daily or weekday numbers.")
            }
        default: throw HomeError("Use time to change an existing calendar event's local time.")
        }
        return true
    }
}

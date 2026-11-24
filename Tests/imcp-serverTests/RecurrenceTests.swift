import EventKit
import Foundation
import XCTest

final class RecurrenceTests: XCTestCase {
    func testOrdinalRuleEndsOnLocalDayOfDSTChange() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let rule = try RemindersService.recurrenceRule(
            from: [
                "frequency": "monthly", "daysOfTheWeek": ["first monday"],
                "end": ["date": "2025-11-02"],
            ],
            timeZone: zone
        )
        XCTAssertEqual(rule.frequency, .monthly)
        XCTAssertEqual(rule.daysOfTheWeek?.first?.dayOfTheWeek, .monday)
        XCTAssertEqual(rule.daysOfTheWeek?.first?.weekNumber, 1)
        XCTAssertEqual(rule.recurrenceEnd?.endDate?.formatted(.iso8601), "2025-11-03T04:59:59Z")
    }

    func testCountAndInvalidEnd() throws {
        let rule = try RemindersService.recurrenceRule(from: [
            "frequency": "weekly", "interval": 2, "end": ["count": 5],
        ])
        XCTAssertEqual(rule.interval, 2)
        XCTAssertEqual(rule.recurrenceEnd?.occurrenceCount, 5)
        XCTAssertThrowsError(
            try RemindersService.recurrenceRule(from: [
                "frequency": "daily", "end": ["count": 2, "date": "2025-10-01"],
            ])
        )
    }
    func testListDeletionRequiresKnownEmptyListWithoutConfirmation() throws {
        XCTAssertThrowsError(try RemindersService.checkUnconfirmedDeletion(count: nil, listName: "Fixture"))
        XCTAssertThrowsError(try RemindersService.checkUnconfirmedDeletion(count: 1, listName: "Fixture"))
        XCTAssertNoThrow(try RemindersService.checkUnconfirmedDeletion(count: 0, listName: "Fixture"))
    }

    func testDateOnlyReminderRemainsUntimedAndKeepsExplicitAlert() async throws {
        let item = EKReminder(eventStore: EKEventStore())
        try await RemindersService.shared.apply(["due": "2026-12-02T12:00:00+01:00", "alarms": [15]], to: item)
        try await RemindersService.shared.apply(["due": "2026-12-05"], to: item)
        XCTAssertEqual(item.dueDateComponents?.day, 5)
        XCTAssertNil(item.dueDateComponents?.hour)
        XCTAssertNil(item.dueDateComponents?.minute)
        XCTAssertEqual(item.alarms?.first?.relativeOffset, -900)
    }

    func testStrictCivilDatesAndNamedTimeZone() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        func parse(_ text: String) -> String? {
            ISO8601DateFormatter.lenientDate(fromISO8601String: text, timeZone: zone)?.formatted(.iso8601)
        }
        XCTAssertNil(parse("2025-02-30T10:00:00Z"))
        XCTAssertNil(parse("2025-02-29"))
        XCTAssertNil(parse("2024-02-29trailing"))
        XCTAssertNotNil(parse("2024-02-29"))
        XCTAssertEqual(parse("2026-03-10T09:00:00"), "2026-03-10T13:00:00Z")
        XCTAssertEqual(parse("2026-03-10T09:00:00+01:00"), "2026-03-10T08:00:00Z")
    }

    func testCoordinatesAcceptIntegersAndRejectInvalidLatitudes() throws {
        let data = Data(#"{"latitude":59,"longitude":18}"#.utf8)
        let args = try JSONDecoder().decode([String: Value].self, from: data)
        XCTAssertEqual(try args.location().coordinate.latitude, 59)
        XCTAssertThrowsError(try ["latitude": Value.int(91), "longitude": .int(18)].location())
    }

}

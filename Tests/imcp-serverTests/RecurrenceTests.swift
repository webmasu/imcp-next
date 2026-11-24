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
}

import Foundation
import XCTest

final class WeatherHistoryTests: XCTestCase {
    func testLocalDaysAcrossStockholmClockChanges() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "Europe/Stockholm"))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func interval(_ date: String) throws -> DateInterval {
            try WeatherService.historyInterval(start: date, end: date, zone: zone, now: now)
        }
        XCTAssertEqual(try interval("2025-03-30").duration, 23 * 3600)
        XCTAssertEqual(try interval("2025-10-26").duration, 25 * 3600)
        XCTAssertThrowsError(try interval("2025-02-30"))
        XCTAssertThrowsError(try interval("2021-07-31"))
        XCTAssertThrowsError(
            try WeatherService.historyInterval(start: "2025-10-17", end: "2025-10-27", zone: zone, now: now)
        )
        XCTAssertNoThrow(
            try WeatherService.historyInterval(start: "2025-10-17", end: "2025-10-26", zone: zone, now: now)
        )
    }
}

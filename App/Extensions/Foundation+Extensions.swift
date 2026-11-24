import Foundation
import os

extension FileManager {
    /// The user's home folder, read from the password database.
    ///
    /// In the App Sandbox,
    /// `NSHomeDirectory()` and `homeDirectoryForCurrentUser` return the app's container,
    /// and the home folder is not always `/Users/<name>`:
    /// it can be moved, for example to another volume.
    static let userHomeDirectoryURL = URL(
        fileURLWithPath: getpwuid(getuid())?.pointee.pw_dir.map { String(cString: $0) } ?? "/Users/\(NSUserName())",
        isDirectory: true
    )
}

extension ISO8601DateFormatter {
    /// Attempts to parse a date string using common ISO 8601 variants,
    /// falling back to local-time parsing when no timezone is present.
    /// - Parameters:
    ///   - dateString: The string representation of the date.
    /// - Returns: A `Date` object if parsing is successful with any format, otherwise `nil`.
    static func lenientDate(fromISO8601String dateString: String, timeZone: TimeZone = .current) -> Date? {
        // Foundation's ISO formatter rolls impossible dates into the following month.
        // Validate the civil day and the complete input before interpreting its offset.
        let pattern =
            #"^[0-9]{4}-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])([Tt ]([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]+)?([Zz]|[+-]([01][0-9]|2[0-3])(:?[0-5][0-9])?)?)?\z"#
        guard dateString.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let civil = DateFormatter()
        civil.locale = Locale(identifier: "en_US_POSIX")
        civil.calendar = Calendar(identifier: .gregorian)
        civil.timeZone = TimeZone.gmt
        civil.isLenient = false
        civil.dateFormat = "yyyy-MM-dd"
        let day = String(dateString.prefix(10))
        guard let checked = civil.date(from: day), civil.string(from: checked) == day else { return nil }

        var value = dateString.uppercased().replacingOccurrences(of: " ", with: "T")
        if value.count == 10 {
            civil.timeZone = timeZone
            return civil.date(from: day)
        }
        if let offset = value.dropFirst(10).firstIndex(where: { $0 == "+" || $0 == "-" }),
            value.distance(from: offset, to: value.endIndex) == 3
        {
            value += ":00"
        }
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        let hasOffset = value.dropFirst(10).contains(where: { "+-Z".contains($0) })
        if !hasOffset {
            civil.timeZone = timeZone
            civil.dateFormat = value.contains(".") ? "yyyy-MM-dd'T'HH:mm:ss.SSS" : "yyyy-MM-dd'T'HH:mm:ss"
            return civil.date(from: value)
        }
        formatter.formatOptions =
            value.contains(".") ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter.date(from: value)
    }

    /// Attempts to parse a date string using common ISO 8601 variants,
    /// falling back to local-time parsing when no timezone is present.
    /// - Parameters:
    ///   - dateString: The string representation of the date.
    /// - Returns: A tuple containing the `Date` object and a boolean indicating if the date is date-only.
    static func parsedLenientISO8601Date(
        fromISO8601String dateString: String,
        timeZone: TimeZone = .current
    ) -> (date: Date, isDateOnly: Bool)? {
        let isDateOnly = isDateOnlyISO8601String(dateString)
        guard let date = lenientDate(fromISO8601String: dateString, timeZone: timeZone) else {
            return nil
        }
        return (date, isDateOnly)
    }

    /// Checks if a date string is a date-only ISO 8601 string.
    /// - Parameters:
    ///   - dateString: The string representation of the date.
    /// - Returns: A boolean indicating if the date is date-only.
    static func isDateOnlyISO8601String(_ dateString: String) -> Bool {
        dateString.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }
}

extension Calendar {
    /// Normalizes a start date to ensure it is a date-only date.
    /// - Parameters:
    ///   - date: The date to normalize.
    ///   - isDateOnly: A boolean indicating if the date is date-only.
    /// - Returns: The normalized date.
    func normalizedStartDate(from date: Date, isDateOnly: Bool) -> Date {
        isDateOnly ? startOfDay(for: date) : date
    }

    /// Normalizes an end date to ensure it is a date-only date.
    /// - Parameters:
    ///   - date: The date to normalize.
    ///   - isDateOnly: A boolean indicating if the date is date-only.
    /// - Returns: The normalized date.
    func normalizedEndDate(from date: Date, isDateOnly: Bool) -> Date {
        guard isDateOnly else { return date }
        let startOfDay = startOfDay(for: date)
        return self.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    }
}

extension NSAppleScript {
    /// An AppleScript compilation or execution error.
    struct ExecutionError: Error, Equatable, Sendable {
        /// The AppleScript error number, such as -1743 when the user has not allowed
        /// iMCP to send Apple events to the target app.
        let number: Int?
        let message: String

        init(number: Int?, message: String) {
            self.number = number
            self.message = message
        }

        init(errorInfo: NSDictionary?) {
            number = (errorInfo?[NSAppleScript.errorNumber] as? NSNumber)?.intValue
            message =
                errorInfo?[NSAppleScript.errorMessage] as? String
                ?? errorInfo.map { String(describing: $0) }
                ?? "unknown error"
        }
    }

    /// Creates and runs each script in one block, off the main thread.
    /// Script objects are not shared between queue blocks.
    /// Tests hold this queue to keep a script waiting.
    static let executionQueue = DispatchQueue(label: "me.mattt.iMCP.AppleScript")

    /// Compiles `source` and runs it on a serial queue, off the main thread.
    ///
    /// A task cancelled before its script starts runs nothing:
    /// cancellation is checked before the script is queued
    /// and again on the queue, after compiling and before any Apple event is sent.
    /// A script that has started runs to the end.
    ///
    /// - Returns: The result of the script.
    /// - Throws: ``ExecutionError`` when the script does not compile or fails,
    ///   or `CancellationError` when the task is cancelled before the script starts.
    static func execute(_ source: String, arguments: [String]? = nil) async throws -> NSAppleEventDescriptor {
        try Task.checkCancellation()
        let isCancelled = OSAllocatedUnfairLock(initialState: false)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                executionQueue.async {
                    guard let script = NSAppleScript(source: source) else {
                        continuation.resume(
                            throwing: ExecutionError(number: nil, message: "the script could not be loaded")
                        )
                        return
                    }
                    var errorInfo: NSDictionary?
                    guard script.compileAndReturnError(&errorInfo) else {
                        continuation.resume(throwing: ExecutionError(errorInfo: errorInfo))
                        return
                    }
                    errorInfo = nil
                    // The last point before an Apple event can be sent.
                    if isCancelled.withLock({ $0 }) {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    let result: NSAppleEventDescriptor
                    if let arguments {
                        // Pass untrusted text as Apple event parameters to a fixed handler.
                        let event = NSAppleEventDescriptor(
                            eventClass: 0x61736372,
                            eventID: 0x70736272,
                            targetDescriptor: nil,
                            returnID: -1,
                            transactionID: 0
                        )
                        event.setParam(NSAppleEventDescriptor(string: "performtask"), forKeyword: 0x736e616d)
                        let parameters = NSAppleEventDescriptor.list()
                        for (index, value) in arguments.enumerated() {
                            parameters.insert(NSAppleEventDescriptor(string: value), at: index + 1)
                        }
                        event.setParam(parameters, forKeyword: 0x2d2d2d2d)
                        result = script.executeAppleEvent(event, error: &errorInfo)
                    } else {
                        result = script.executeAndReturnError(&errorInfo)
                    }
                    if errorInfo != nil {
                        continuation.resume(throwing: ExecutionError(errorInfo: errorInfo))
                    } else {
                        continuation.resume(returning: result)
                    }
                }
            }
        } onCancel: {
            isCancelled.withLock { $0 = true }
        }
    }
}

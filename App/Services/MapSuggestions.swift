import Foundation
import MapKit

extension MapsService {
    static var distance: Tool {
        Tool(
            name: "maps_distance",
            description: "Geodesic distance between coordinates in metres.",
            inputSchema: .object(
                properties: [
                    "originLatitude": .number(), "originLongitude": .number(),
                    "destinationLatitude": .number(), "destinationLongitude": .number(),
                ],
                required: ["originLatitude", "originLongitude", "destinationLatitude", "destinationLongitude"],
                additionalProperties: false
            ),
            annotations: .init(title: "Straight-Line Distance", readOnlyHint: true, openWorldHint: false)
        ) { args in
            let origin = try args.location(latitude: "originLatitude", longitude: "originLongitude")
            let destination = try args.location(latitude: "destinationLatitude", longitude: "destinationLongitude")
            return ["meters": origin.distance(from: destination)]
        }
    }

    static var autocomplete: Tool {
        Tool(
            name: "maps_autocomplete",
            description: "Suggest addresses and places for a partial query. Optional coordinates bias suggestions.",
            inputSchema: .object(
                properties: ["query": .string(), "latitude": .number(), "longitude": .number()],
                required: ["query"],
                additionalProperties: false
            ),
            annotations: .init(title: "Suggest Addresses", readOnlyHint: true, openWorldHint: true)
        ) { args in
            let center = (args["latitude"] != nil || args["longitude"] != nil) ? try args.location().coordinate : nil
            return try await MapSuggestions().search(query: args.requiredText("query"), center: center)
        }
    }
}

/// Each pending request owns its delegate, continuation and timeout.
@MainActor
private final class MapSuggestions: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var continuation: CheckedContinuation<[[String: String]], Error>?
    private var timeout: Task<Void, Never>?

    func search(query: String, center: CLLocationCoordinate2D?) async throws -> [[String: String]] {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                completer.delegate = self
                completer.resultTypes = [.address, .pointOfInterest]
                if let center {
                    completer.region = MKCoordinateRegion(
                        center: center,
                        latitudinalMeters: 10000,
                        longitudinalMeters: 10000
                    )
                }
                timeout = Task {
                    do { try await Task.sleep(for: .seconds(15)) } catch { return }
                    finish(.failure(ToolInputError("Map suggestions timed out.")))
                }
                completer.queryFragment = query
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError())) }
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        finish(.success(completer.results.map { ["title": $0.title, "subtitle": $0.subtitle] }))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<[[String: String]], Error>) {
        let pending = continuation
        continuation = nil
        completer.delegate = nil
        completer.cancel()
        timeout?.cancel()
        timeout = nil
        pending?.resume(with: result)
    }
}

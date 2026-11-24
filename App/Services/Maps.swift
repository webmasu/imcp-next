import Foundation
import MapKit
import OSLog
import Ontology

private let log = Logger.service("maps")

private let defaultSearchRadius: CLLocationDistance = 5000  // Default 5km
private let defaultSearchLimit: Int = 10
private let defaultMapImageSize: CGSize = CGSize(width: 1024, height: 1024)

final class MapsService: NSObject, Service {
    static let shared = MapsService()

    var isActivated: Bool {
        get async {
            // MapKit doesn't require explicit permission, but we rely on location
            return await LocationService.shared.isActivated
        }
    }

    func activate() async throws {
        log.debug("Activating maps service")
        // Maps service depends on location service being active
        try await LocationService.shared.activate()
    }

    var tools: [Tool] {
        Self.autocomplete
        Self.distance
        Tool(
            name: "maps_search",
            description: "Search for places, addresses, points of interest by text query",
            inputSchema: .object(
                properties: [
                    "query": .string(
                        description: "Search text (place name, address, etc.)"
                    ),
                    "limit": .integer(description: "Maximum results to return", minimum: 1),
                    "region": .object(
                        description: "Region to bias search results",
                        properties: [
                            "latitude": .number(),
                            "longitude": .number(),
                            "radius": .number(
                                description: "Search radius in meters",
                                default: .double(defaultSearchRadius)
                            ),
                        ],
                        required: ["latitude", "longitude"],
                        additionalProperties: false
                    ),
                ],
                required: ["query"],
                additionalProperties: false
            ),
            annotations: .init(
                title: "Search Places",
                readOnlyHint: true,
                openWorldHint: true
            )
        ) { arguments in
            guard let query = arguments["query"]?.stringValue else {
                throw NSError(
                    domain: "MapsServiceError",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Search query is required"]
                )
            }

            // Set up search request
            let searchRequest = MKLocalSearch.Request()
            searchRequest.naturalLanguageQuery = query

            // Configure region if provided
            let limit = arguments["limit"]?.intValue ?? Int.max
            guard limit > 0 else { throw ToolInputError("limit must be positive.") }
            if let regionArg = arguments["region"]?.objectValue {
                let center = try regionArg.location().coordinate
                let radius = regionArg["radius"]?.numericValue ?? defaultSearchRadius
                guard radius > 0 else { throw ToolInputError("radius must be positive.") }
                let region = MKCoordinateRegion(
                    center: center,
                    latitudinalMeters: radius,
                    longitudinalMeters: radius
                )
                searchRequest.region = region
            }

            return try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<[Place], Error>) in

                let search = MKLocalSearch(request: searchRequest)
                search.start { response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let response = response else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "MapsServiceError",
                                code: 2,
                                userInfo: [NSLocalizedDescriptionKey: "No search results"]
                            )
                        )
                        return
                    }

                    // Convert MKMapItems to Ontology Place objects
                    let places = response.mapItems.prefix(limit).map { item -> Place in
                        return Place(item)
                    }

                    continuation.resume(returning: places)
                }
            }
        }

        Tool(
            name: "maps_directions",
            description: """
                Get driving, cycling or walking directions, or a transit estimate with departure, arrival, distance and an Apple Maps link.
                """,
            inputSchema: .object(
                properties: [
                    "originAddress": .string(
                        description: "Origin address"
                    ),
                    "originCoordinates": .object(
                        description: "Origin coordinates",
                        properties: [
                            "latitude": .number(),
                            "longitude": .number(),
                        ],
                        required: ["latitude", "longitude"],
                        additionalProperties: false
                    ),
                    "destinationAddress": .string(
                        description: "Destination address"
                    ),
                    "destinationCoordinates": .object(
                        description: "Destination coordinates",
                        properties: [
                            "latitude": .number(),
                            "longitude": .number(),
                        ],
                        required: ["latitude", "longitude"],
                        additionalProperties: false
                    ),
                    "transportType": .string(
                        description: "Transport type for the route",
                        default: "automobile",
                        enum: ["automobile", "walking", "cycling", "transit", "any"]
                    ),
                ],
                additionalProperties: false
            ),
            annotations: .init(
                title: "Get Directions",
                readOnlyHint: true,
                openWorldHint: true
            )
        ) { arguments in
            // Need either origin address or coordinates
            guard
                arguments["originAddress"]?.stringValue != nil
                    || (arguments["originCoordinates"]?.objectValue?["latitude"]?.numericValue != nil
                        && arguments["originCoordinates"]?.objectValue?["longitude"]?.numericValue
                            != nil)
            else {
                throw NSError(
                    domain: "MapsServiceError",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Origin address or coordinates required"]
                )
            }

            // Need either destination address or coordinates
            guard
                arguments["destinationAddress"]?.stringValue != nil
                    || (arguments["destinationCoordinates"]?.objectValue?["latitude"]?.numericValue
                        != nil
                        && arguments["destinationCoordinates"]?.objectValue?["longitude"]?
                            .numericValue != nil)
            else {
                throw NSError(
                    domain: "MapsServiceError",
                    code: 4,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Destination address or coordinates required"
                    ]
                )
            }

            let transportType: MKDirectionsTransportType
            switch arguments["transportType"]?.stringValue {
            case "automobile":
                transportType = .automobile
            case "cycling": transportType = .cycling
            case "walking":
                transportType = .walking
            case "transit":
                transportType = .transit
            default:
                transportType = .any
            }

            // Get origin and destination
            let originItem = try await self.getMapItem(
                address: arguments["originAddress"]?.stringValue,
                coordinates: arguments["originCoordinates"]?.objectValue
            )

            let destinationItem = try await self.getMapItem(
                address: arguments["destinationAddress"]?.stringValue,
                coordinates: arguments["destinationCoordinates"]?.objectValue
            )

            // Set up directions request
            let directionsRequest = MKDirections.Request()
            directionsRequest.source = originItem
            directionsRequest.destination = destinationItem
            directionsRequest.transportType = transportType

            let directions = MKDirections(request: directionsRequest)
            if transportType == .transit {
                return MapTrip.estimate(try await directions.calculateETA(), transportType)
            }
            let response = try await directions.calculate()
            guard !response.routes.isEmpty else { throw ToolInputError("No routes found.") }
            return MapTrip.route(Trip(response))

        }

        Tool(
            name: "maps_explore",
            description: "Find points of interest near a location",
            inputSchema: .object(
                properties: [
                    "category": .string(
                        description: "POI category",
                        enum: MKPointOfInterestCategory.allCases.map { .string($0.stringValue) }
                    ),
                    "latitude": .number(),
                    "longitude": .number(),
                    "radius": .number(
                        description: "Search radius in meters",
                        default: .double(defaultSearchRadius)
                    ),
                    "limit": .integer(
                        description: "Maximum results to return",
                        default: .int(defaultSearchLimit)
                    ),
                ],
                required: ["category", "latitude", "longitude"],
                additionalProperties: false
            ),
            annotations: .init(
                title: "Find Nearby Points of Interest",
                readOnlyHint: true,
                openWorldHint: true
            )
        ) { arguments in
            guard let categoryString = arguments["category"]?.stringValue,
                let latitude = arguments["latitude"]?.numericValue,
                let longitude = arguments["longitude"]?.numericValue
            else {
                throw NSError(
                    domain: "MapsServiceError",
                    code: 6,
                    userInfo: [NSLocalizedDescriptionKey: "Category and coordinates are required"]
                )
            }

            let radius = arguments["radius"]?.numericValue ?? defaultSearchRadius
            let limit = arguments["limit"]?.intValue ?? defaultSearchLimit

            guard CLLocationCoordinate2DIsValid(.init(latitude: latitude, longitude: longitude)),
                radius > 0, radius <= MKLocalPointsOfInterestRequest.maxRadius, limit > 0
            else {
                throw ToolInputError("Invalid point-of-interest search radius or result limit.")
            }
            guard let category = MKPointOfInterestCategory.from(string: categoryString) else {
                throw NSError(
                    domain: "MapsServiceError",
                    code: 7,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid POI category"]
                )
            }

            // Create search request
            let request = MKLocalPointsOfInterestRequest(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                radius: radius
            )
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])

            return try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<[Place], Error>) in

                let search = MKLocalSearch(request: request)
                search.start { response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let response = response else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "MapsServiceError",
                                code: 8,
                                userInfo: [NSLocalizedDescriptionKey: "No POI results found"]
                            )
                        )
                        return
                    }

                    // Convert MKMapItems to Value objects
                    let places = response.mapItems.prefix(limit).map { item -> Place in
                        return Place(item)
                    }

                    continuation.resume(returning: places)
                }
            }
        }

        Tool(
            name: "maps_eta",
            description: "Calculate estimated travel time between two locations",
            inputSchema: .object(
                properties: [
                    "originLatitude": .number(),
                    "originLongitude": .number(),
                    "destinationLatitude": .number(),
                    "destinationLongitude": .number(),
                    "transportType": .string(
                        description: "Transport type",
                        default: "automobile",
                        enum: ["automobile", "walking", "cycling", "transit"]
                    ),
                ],
                required: [
                    "originLatitude", "originLongitude", "destinationLatitude",
                    "destinationLongitude",
                ],
                additionalProperties: false
            ),
            annotations: .init(
                title: "Get Estimated Travel Time",
                readOnlyHint: true,
                openWorldHint: true
            )
        ) { arguments in
            let origin = try arguments.location(latitude: "originLatitude", longitude: "originLongitude")
            let destination = try arguments.location(latitude: "destinationLatitude", longitude: "destinationLongitude")
            let originPlacemark = MKPlacemark(coordinate: origin.coordinate)
            let destPlacemark = MKPlacemark(coordinate: destination.coordinate)

            // Create map items from placemarks
            let originItem = MKMapItem(placemark: originPlacemark)
            let destinationItem = MKMapItem(placemark: destPlacemark)

            // Set up directions request
            let directionsRequest = MKDirections.Request()
            directionsRequest.source = originItem
            directionsRequest.destination = destinationItem

            // Set transport type
            if let transportTypeStr = arguments["transportType"]?.stringValue {
                switch transportTypeStr {
                case "automobile":
                    directionsRequest.transportType = .automobile
                case "cycling": directionsRequest.transportType = .cycling
                case "walking":
                    directionsRequest.transportType = .walking
                case "transit":
                    directionsRequest.transportType = .transit
                default:
                    directionsRequest.transportType = .automobile
                }
            } else {
                directionsRequest.transportType = .automobile
            }

            let response = try await MKDirections(request: directionsRequest).calculateETA()
            return MapTrip.estimate(response, directionsRequest.transportType)

        }

        Tool(
            name: "maps_generate",
            description: "Generate a static map image for given coordinates and parameters",
            inputSchema: .object(
                properties: [
                    "latitude": .number(),
                    "longitude": .number(),
                    "latitudeDelta": .number(
                        description: "Latitude degrees visible on map"
                    ),
                    "longitudeDelta": .number(
                        description: "Longitude degrees visible on map"
                    ),
                    "width": .integer(
                        description: "Image width in pixels",
                        default: .int(Int(defaultMapImageSize.width))
                    ),
                    "height": .integer(
                        description: "Image height in pixels",
                        default: .int(Int(defaultMapImageSize.height))
                    ),
                    "mapType": .string(
                        description: "Map type",
                        default: "standard",
                        enum: ["standard", "satellite", "hybrid", "mutedStandard"]
                    ),
                    "showPointsOfInterest": .oneOf(
                        [
                            .boolean(
                                description: "Show all (true) or no (false) POIs",
                                default: false
                            ),
                            .array(
                                description: "Specific POI types to show",
                                items: .anyOf(
                                    MKPointOfInterestCategory.allCases.map {
                                        .string(const: .string($0.stringValue))
                                    }
                                ),
                                minItems: 1
                            ),
                        ]
                    ),
                    "showBuildings": .boolean(
                        description: "Whether to show buildings",
                        default: false
                    ),
                ],
                required: ["latitude", "longitude", "latitudeDelta", "longitudeDelta"],
                additionalProperties: false
            ),
            annotations: .init(
                title: "Generate Map Image",
                readOnlyHint: true,
                openWorldHint: true
            )
        ) { arguments in
            guard let latitude = arguments["latitude"]?.numericValue,
                let longitude = arguments["longitude"]?.numericValue,
                let latitudeDelta = arguments["latitudeDelta"]?.numericValue,
                let longitudeDelta = arguments["longitudeDelta"]?.numericValue
            else {
                throw NSError(
                    domain: "MapsServiceError",
                    code: 13,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Latitude, longitude, latitudeDelta, and longitudeDelta are required"
                    ]
                )
            }

            guard CLLocationCoordinate2DIsValid(.init(latitude: latitude, longitude: longitude)),
                latitudeDelta > 0, latitudeDelta <= 180, longitudeDelta > 0, longitudeDelta <= 360
            else {
                throw ToolInputError("Invalid map region.")
            }
            let width = arguments["width"]?.intValue ?? Int(defaultMapImageSize.width)
            let height = arguments["height"]?.intValue ?? Int(defaultMapImageSize.height)
            let mapTypeString = arguments["mapType"]?.stringValue ?? "standard"

            let options = MKMapSnapshotter.Options()

            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let span = MKCoordinateSpan(
                latitudeDelta: latitudeDelta,
                longitudeDelta: longitudeDelta
            )
            options.region = MKCoordinateRegion(center: center, span: span)

            switch mapTypeString {
            case "satellite":
                options.mapType = .satellite
            case "hybrid":
                options.mapType = .hybrid
            case "mutedStandard":
                options.mapType = .mutedStandard
            default:
                options.mapType = .standard
            }

            options.size = CGSize(width: width, height: height)

            let filter: MKPointOfInterestFilter
            switch arguments["showPointsOfInterest"] {
            case .bool(true), .string("true"):
                filter = .includingAll
            case .bool(false), .string("false"):
                filter = .excludingAll
            case let .string(string):
                do {
                    let jsonData = string.data(using: .utf8)!
                    let poiStrings = try JSONDecoder().decode([String].self, from: jsonData)
                    let categories = poiStrings.compactMap {
                        MKPointOfInterestCategory.from(string: $0)
                    }
                    filter = categories.isEmpty ? .excludingAll : .init(including: categories)
                } catch {
                    filter = .excludingAll
                }
            case let .array(poiTypes):
                let categories = poiTypes.compactMap { $0.stringValue }.compactMap {
                    MKPointOfInterestCategory.from(string: $0)
                }
                filter = categories.isEmpty ? .excludingAll : .init(including: categories)
            default:
                filter = .excludingAll
            }
            options.pointOfInterestFilter = filter

            options.showsBuildings = arguments["showBuildings"]?.boolValue == true

            return try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Value, Error>) in

                let snapshotter = MKMapSnapshotter(options: options)
                snapshotter.start { snapshot, error in
                    if let error = error {
                        log.error("Map snapshot failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let snapshot = snapshot else {
                        log.error("Map snapshot failed: No snapshot data")
                        continuation.resume(
                            throwing: NSError(
                                domain: "MapsServiceError",
                                code: 14,
                                userInfo: [
                                    NSLocalizedDescriptionKey: "Failed to generate map snapshot"
                                ]
                            )
                        )
                        return
                    }

                    // Get image representation (e.g., PNG)
                    guard let imageData = snapshot.image.tiffRepresentation,
                        let bitmap = NSBitmapImageRep(data: imageData),
                        let pngData = bitmap.representation(using: .png, properties: [:])
                    else {
                        log.error("Map snapshot failed: Could not convert image to PNG")
                        continuation.resume(
                            throwing: NSError(
                                domain: "MapsServiceError",
                                code: 15,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "Failed to convert snapshot to PNG format"
                                ]
                            )
                        )
                        return
                    }

                    continuation.resume(
                        returning: .data(mimeType: "image/png", pngData)
                    )
                }
            }
        }
    }

    // MARK: - Helper methods

    private func getMapItem(address: String?, coordinates: [String: Value]?) async throws
        -> MKMapItem
    {
        if let address = address {
            // Use geocoding to get location from address
            let searchRequest = MKLocalSearch.Request()
            searchRequest.naturalLanguageQuery = address

            let search = MKLocalSearch(request: searchRequest)
            let response = try await search.start()

            guard let mapItem = response.mapItems.first else {
                throw NSError(
                    domain: "MapsServiceError",
                    code: 11,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Could not find location for address: \(address)"
                    ]
                )
            }

            return mapItem
        } else if let coordinates {
            let placemark = try MKPlacemark(coordinate: coordinates.location().coordinate)
            return MKMapItem(placemark: placemark)
        } else {
            throw NSError(
                domain: "MapsServiceError",
                code: 12,
                userInfo: [
                    NSLocalizedDescriptionKey: "Either address or coordinates must be provided"
                ]
            )
        }
    }
}

private enum MapTrip: Encodable {
    case route(Trip)
    case estimate(MKDirections.ETAResponse, MKDirectionsTransportType)

    enum CodingKeys: String, CodingKey { case distanceMeters, travelTimeSeconds, mapsURL }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .route(let trip):
            try trip.encode(to: encoder)
        case .estimate(let response, let transport):
            try encodeEstimate(response, transport: transport, to: encoder)
        }
    }

    private func encodeEstimate(
        _ response: MKDirections.ETAResponse,
        transport: MKDirectionsTransportType,
        to encoder: Encoder
    ) throws {
        try Trip(response).encode(to: encoder)
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(response.distance, forKey: .distanceMeters)
        try fields.encode(response.expectedTravelTime, forKey: .travelTimeSeconds)
        let origin = response.source.placemark.coordinate
        let destination = response.destination.placemark.coordinate
        var url = URLComponents()
        url.scheme = "https"
        url.host = "maps.apple.com"
        url.path = "/"
        let flag: String
        switch transport {
        case .transit: flag = "r"
        case .walking: flag = "w"
        case .cycling: flag = "b"
        default: flag = "d"
        }
        url.queryItems = [
            .init(name: "saddr", value: "\(origin.latitude),\(origin.longitude)"),
            .init(name: "daddr", value: "\(destination.latitude),\(destination.longitude)"),
            .init(name: "dirflg", value: flag),
        ]
        try fields.encode(url.url, forKey: .mapsURL)
    }
}

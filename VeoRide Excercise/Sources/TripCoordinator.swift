import MapKit

/// Delegate protocol for reponding to events from `TripCoordinator`.
protocol TripCoordinatorDelegate: class {

    /// Indicates that the user should be asked to allow location usage for the app in order to enable trip functionality.
    /// - Parameters:
    ///     - locationManager: A location manager object on which access may be requested.
    ///     - coordinator: The `TripCoordinator` object which needs this access.
    func locationUsageAuthorizationRequired(by locationManager: CLLocationManager, in coordinator: TripCoordinator)

    /// Indicates that the user has been previously asked to provide location access but denied, and should
    /// be directed to Settings to enable it.
    /// - Parameter coordinator: The `TripCoordinator` object which needs this access.
    func locationUsageUnavailable(in coordinator: TripCoordinator)

    /// Called when a requested trip route has completed successfully, providing the response.
    /// - Parameters:
    ///     - response: The response object containing the route information for display on a map. Guaranteed
    ///     to contain at least one route.
    ///     - coordinator: The `TripCoordinator` object on which the route request was initiatied.
    func tripRouteDidComplete(with response: MKDirections.Response, in coordinator: TripCoordinator)

    /// Called when a requested trip route failed to complete, providing the error.
    /// - Parameters:
    ///     - error: The object containing information relating to why the failure occurred, if available.
    ///     - coordinator: The `TripCoordinator` object on which the route request was initiatied.
    func tripRouteDidFail(with error: Swift.Error, in coordinator: TripCoordinator)
}

/// Manages trip calculation functionality (and its prerequisites) on behalf of `TripViewController`. Provides
/// `TripCoordinatorDelegate` for responding to events.
final class TripCoordinator: NSObject {

    /// The delegate to receive event updates from this object.
    ///
    /// Setting this property will immediately invoke the relevant location usage delegate
    /// method if location usage has not been granted by the user.
    weak var delegate: TripCoordinatorDelegate? {
        didSet { notifyLocationAuthorizationStatusIfNeeded() }
    }

    /// Indicates whether location authorization is still required to enable trip functionality.
    var needsLocationUseAuthorization: Bool {
        CLLocationManager.authorizationStatus() != .authorizedWhenInUse
    }

    /// Executes an `MKDirections` request between the provided points and calls the appropriate `TripCoordinatorDelegate`
    /// method upon completion.
    /// - Parameters:
    ///     - userLocation: The beginning point for the route.
    ///     - destination: The ending point for the route.
    func route(from userLocation: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: .init(coordinate: userLocation, addressDictionary: nil))
        request.destination = MKMapItem(placemark: .init(coordinate: destination, addressDictionary: nil))
        request.transportType = .walking

        //TODO: Enable multi-route functionality
        //Note: Actually we seem to always get alternate routes when walking (edit: perhaps only in simulator?)
        request.requestsAlternateRoutes = false

        MKDirections(request: request).calculate {
            switch ($0, $1) {
            case (.some(let directions), _) where !directions.routes.isEmpty:
                self.delegate?.tripRouteDidComplete(with: directions, in: self)
            case (_, .some(let error)):
                self.delegate?.tripRouteDidFail(with: error, in: self)
            default:
                self.delegate?.tripRouteDidFail(with: Error.unknownRoutingError, in: self)
            }
        }
    }

    /// Returns a map region appropriate for displaying all provided routes simultaneously with an optional zoom offset.
    /// - Parameters:
    ///     - routes: The routes to be included in the generated map region.
    ///     - zoomLevel: The amount to zoom the generated region. If not specified, the returned region will
    ///     just-enclose the provided routes. Positive values zoom in while negative values zoom out.
    func generateMapRegion(for routes: [MKRoute], zoomLevel: CLLocationDegrees = 0) -> MKCoordinateRegion {
        return generateMapRegion(for: routes.map { $0.polyline }, zoomLevel: zoomLevel)
    }

    /// Returns a map region appropriate for displaying all provided overlays simultaneously with an optional zoom offset.
    /// - Parameters:
    ///     - overlays: The overlays to be included in the generated map region.
    ///     - zoomLevel: The amount to zoom the generated region. If not specified, the returned region will
    ///     just-enclose the provided overlays. Positive values zoom in while negative values zoom out.
    func generateMapRegion(for overlays: [MKOverlay], zoomLevel: CLLocationDegrees = 0) -> MKCoordinateRegion {
        let routeRectUnion = overlays.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) }
        var region = MKCoordinateRegion(routeRectUnion)
        region.span.longitudeDelta -= zoomLevel
        region.span.latitudeDelta -= zoomLevel * 2
        return region
    }

    /// Calculate the total distance traveled between all points in the provided collection.
    /// - parameter userPath: The collection of points whose distance should be summed.
    func calculateDistanceTraveled(on userPath: [CLLocationCoordinate2D]) -> CLLocationDistance {
        var lastPoint: MKMapPoint?
        var distances: [CLLocationDistance] = []
        
        for point in userPath.map(MKMapPoint.init) {
            if let lastPoint = lastPoint {
                distances.append(lastPoint.distance(to: point))
            }
            lastPoint = point
        }

        return distances.reduce(CLLocationDistance(), +)
    }

    /// Returns the last map point (i.e. the ending point) in the provided route step.
    ///
    /// May be used for determining the user's remaining distance to their next step.
    func retrieveEndpoint(from step: MKRoute.Step) -> MKMapPoint? {
        let stepPointCount = step.polyline.pointCount

        //FIXME: Shouldn't be possible for a line to have no points, but should promote this to an error
        guard stepPointCount > 0 else { return nil }

        return step.polyline.points()[stepPointCount - 1]
    }

    /// Detects if the user's position is within an acceptable range of the provided step's end point to consider it reached.
    /// - Parameters:
    ///     - coordinate: The user's current location.
    ///     - step: The route step which the user is currently navigating towards.
    func userPosition(_ coordinate: CLLocationCoordinate2D, hasReachedStep step: MKRoute.Step) -> Bool {
        //See FIXME in retrieveEndpoint for comments on this failure condition
        guard let stepEndPoint = retrieveEndpoint(from: step) else { return false }

        let userMapPoint = MKMapPoint(coordinate)

        //FIXME: Should add detection for having passed the step end point relative to the ending destination
        //to account for e.g. periods of signal loss
        return userMapPoint.distance(to: stepEndPoint) < 10
    }

    /// Lazily initialzes and configures the location manager object.
    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        return manager
    }()

    /// Immediately notifies the delegate via the corresponding delegate method if the user has either
    /// not yet authorized or explicitly denied location usage for the app.
    private func notifyLocationAuthorizationStatusIfNeeded() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            delegate?.locationUsageAuthorizationRequired(by: locationManager, in: self)
        case .denied, .restricted:
            delegate?.locationUsageUnavailable(in: self)
        default:
            break
        }
    }

    /// A type for encapsulating errors that may occur while performing trip-related actions.
    enum Error: Swift.Error, CustomStringConvertible {

        /// Indicates that trip routing concluded without a response or error object and therefore
        /// no futher information is available.
        ///
        /// We hope that Apple has made this impossible, but due to the (Optional, Optional) result
        /// pattern it is a valid code path that we must handle.
        case unknownRoutingError

        /// Indicates that the user has explicitely prevented location access for the app and it must be enabled in Settings.
        case userLocationUsageIsUnavailable

        var description: String {
            switch self {
            case .unknownRoutingError:
                return "\(type(of: self)): An unknown error occurred while executing a directions request and no information was provided."
            case .userLocationUsageIsUnavailable:
                return "\(type(of: self)): The user has denied location access and it must be manually enabled in Settings."
            }
        }
    }
}

extension TripCoordinator: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted:
            delegate?.locationUsageUnavailable(in: self)
        default:
            break
        }
    }
}

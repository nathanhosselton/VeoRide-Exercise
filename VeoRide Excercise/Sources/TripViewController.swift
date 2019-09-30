import UIKit
import MapKit

final class TripViewController: UIViewController {
    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var startButton: UIButton!

    /// The object which manages the trip calculating capabilities of this controller.
    private let tripCoordinator = TripCoordinator()

    /// The object encapsulating this controller's state.
    private var state = State()

    override func viewDidLoad() {
        super.viewDidLoad()
        tripCoordinator.delegate = self
        //TODO: Configure initial user location detection failure handling
    }

    /// Handler for the map view's tap gesture recognizer, used to determine the map location of the user's tap
    /// and kickoff trip routing.
    @IBAction private func onMapTapped(sender: UITapGestureRecognizer) {
        guard sender.state == .ended else { return }

        //FIXME: Ensure user location presence ahead of time and/or present an error if nil.
        guard let userLocation = mapView.userLocation.location else { return }

        let destination = mapView.convert(sender.location(in: mapView), toCoordinateFrom: mapView)

        //TODO: Determine if tap location is within an alternate route overlay
        //if it is: select that route for navigation
        //if it isn't: continue with new trip routing

        //TODO: Drop a pin on the destination
        //TODO: Show activity indicator

        resetViewState()

        tripCoordinator.route(from: userLocation.coordinate, to: destination)
    }

    /// Handler for the view's Start button, used for initiating navigation.
    @IBAction private func onStartPressed() {
        if state.isNavigating {
            //TODO: End trip, restore button title, color, and enabled state
            //TODO: Display trip summary (time and distance)
            //TODO: Zoom map to travel path
            //TODO: Enable map interaction and remove user tracking
            //TODO: Remove navigation steps
            //TODO: reset state
            return
        }

        //FIXME: Ensure user location presence ahead of time and/or present an error if nil.
        guard let userLocation = mapView.userLocation.location else { return }

        mapView.setUserTrackingMode(.followWithHeading, animated: true)

        //TODO: Enable user interaction and add zoom/tracking reset button if user breaks tracking
        mapView.isUserInteractionEnabled = false

        //Remove any routes from the map that aren't the chosen navigation route
        for case let overlay as MKPolyline in mapView.overlays where overlay != state.activeRoute?.polyline {
            mapView.removeOverlay(overlay)
            //TODO: Remove corresponding routes from state.displayedRoutes
        }

        startButton.setTitle("End", for: .normal)
        startButton.setTitleColor(.red, for: .normal)

        state.set(.userTravelPathPoint(userLocation.coordinate))
        state.set(.navigating(true))

        displayNextNavigationStep()
    }

    private func displayNextNavigationStep() {
        guard state.isNavigating else { return }
        //TODO: Display next navigation step and update when reached
    }

    /// Resets the view to an appropriate state for restarting the trip selection process.
    private func resetViewState() {
        mapView.removeOverlays(mapView.overlays)
        mapView.isUserInteractionEnabled = true
        mapView.setUserTrackingMode(.none, animated: false)
        startButton.isEnabled = false
        startButton.setTitle("Start", for: .normal)
        startButton.setTitleColor(.blue, for: .normal)
        //TODO: clear destination pin

        state = State()
    }

    /// Encapsulates the state and mutation transactions of this controller.
    struct State {
        /// A type repesenting the available mutations on this State.
        enum Mutation {
            case initialZoom
            case displayedRoutes([MKRoute])
            case activeRoute(MKRoute)
            case navigating(Bool)
            case userTravelPathPoint(CLLocationCoordinate2D)
        }

        /// Sets the provided mutation on this object.
        mutating func set(_ mutation: Mutation) {
            switch mutation {
            case .initialZoom:
                State.hasPerformedInitialZoom = true
            case .displayedRoutes(let routes):
                displayedRoutes = routes
                activeRoute = routes.first
            case .activeRoute(let route):
                activeRoute = route
            case .navigating(let value):
                isNavigating = value
            case .userTravelPathPoint(let newPoint):
                userTravelPath.append(newPoint)
            }
        }

        static private var hasPerformedInitialZoom = false

        /// Indicates whether the map has zoomed to the user's location at app launch.
        var hasPerformedInitialZoom: Bool {
            State.hasPerformedInitialZoom
        }

        /// The collection of routes currently displayed on the map. Empty when no routes are displayed.
        private(set) var displayedRoutes: [MKRoute] = []

        /// The route currently selected by the user. Updates when a new route is selected. Nil when no routes are displayed.
        private(set) var activeRoute: MKRoute?

        /// Indicates whether the user has begun navigation of the `activeRoute`.
        private(set) var isNavigating = false

        private(set) var userTravelPath: [CLLocationCoordinate2D] = []
    }

    //MARK: UI Constants

    /// The distance the map should be automatically zoomed when the user is selecting a destination.
    private let defaultMapRegionDistance: CLLocationDistance = 1000

    /// The width of the path drawn to the map for routes to the user's destination.
    private let tripRoutePathWidth: CGFloat = 8

    /// The color of the path drawn to the map for routes to the user's destination.
    private let tripRoutePathColor: UIColor = .blue

    /// The color of the path drawn to the map for the user's path during navigation.
    private let tripUserPathColor: UIColor = .red

    /// The zoom level relative to the edges of a trip route's rectangle.
    private let tripRouteZoomAmount: CLLocationDegrees = -0.002
}

extension TripViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if !state.hasPerformedInitialZoom {
            mapView.setRegion(.init(center: userLocation.coordinate, latitudinalMeters: 0, longitudinalMeters: defaultMapRegionDistance), animated: true)
            state.set(.initialZoom)
        }

        if state.isNavigating {
            //FIXME: Draw a single continuous path using a custom MKOverlay
            if let lastPoint = state.userTravelPath.last {
                mapView.addOverlay(MKPolyline(coordinates: [lastPoint, userLocation.coordinate], count: 2))
            }
            state.set(.userTravelPathPoint(userLocation.coordinate))
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        switch overlay {
        case is MKPolyline:
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.lineWidth = tripRoutePathWidth
            renderer.strokeColor = state.isNavigating ? tripUserPathColor : tripRoutePathColor
            return renderer
        default:
            #if DEBUG
            print("\(type(of: self)) tried to display an unsupported overlay to the map!")
            #endif
            return .init()
        }
    }
}

extension TripViewController: TripCoordinatorDelegate {
    func tripRouteDidComplete(with response: MKDirections.Response, in coordinator: TripCoordinator) {
        mapView.addOverlays(response.routes.map { $0.polyline })
        mapView.setRegion(coordinator.generateMapRegion(for: response.routes, zoomLevel: tripRouteZoomAmount), animated: true)

        startButton.isEnabled = true
        //TODO: Remove activity indicator

        state.set(.displayedRoutes(response.routes))
    }

    func tripRouteDidFail(with error: Error, in coordinator: TripCoordinator) {
        //TODO: Display message to user and reset view state if needed
        //TODO: Disable Start button if needed
    }

    func locationUsageAuthorizationRequired(by locationManager: CLLocationManager, in coordinator: TripCoordinator) {
        locationManager.requestWhenInUseAuthorization()
    }

    func locationUsageUnavailable(in coordinator: TripCoordinator) {
        //TODO: Inform user they must enable location usage in Settings for app functionality
    }
}

//Error messages for display by this view controller
extension TripCoordinator.Error: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unknownRoutingError:
            return "Something went wrong while routing to your destination. Sorry about that. Please try again."
        }
    }
}

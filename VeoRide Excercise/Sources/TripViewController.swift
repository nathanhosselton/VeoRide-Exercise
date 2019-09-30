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
        guard !state.pendingUserClear, sender.state == .ended else { return }

        //FIXME: Ensure user location presence ahead of time and/or present an error if nil.
        guard let userLocation = mapView.userLocation.location else { return }

        let destination = mapView.convert(sender.location(in: mapView), toCoordinateFrom: mapView)

        //TODO: Determine if tap location is within an alternate route overlay
        //if it is: select that route for navigation, recoloring inactive routes gray
        //if it isn't: continue with new trip routing

        //TODO: Drop a pin on the destination
        //TODO: Show activity indicator

        resetViewState()

        tripCoordinator.route(from: userLocation.coordinate, to: destination)
    }

    /// Handler for the view's Start button, used for initiating navigation.
    @IBAction private func onStartPressed() {
        //FIXME: This button is overly responsible.
        if state.pendingUserClear {
            resetViewState()
        } else if state.isNavigating {
            endNavigation()
        } else {
            beginNavigation()
        }
    }

    /// Ends the navigation process and cleans up state.
    private func endNavigation() {
        state.set(.navigating(false))

        mapView.setUserTrackingMode(.none, animated: false)
        mapView.setRegion(tripCoordinator.generateMapRegion(for: mapView.overlays, zoomLevel: tripRouteZoomAmount), animated: true)

        displayTripSummary(distance: tripCoordinator.calculateDistanceTraveled(on: state.userTravelPath), time: state.elapsedTravelTime)

        //TODO: Remove alert and reset state if app is backgrounded while trip summary is displayed
    }

    /// Initiates the navigation process and updates relevant state.
    private func beginNavigation() {
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
        state.set(.travelStartTime)
        state.set(.navigating(true))

        displayNextNavigationStep()
    }

    /// Displays the next navigation step on screen during navigation.
    private func displayNextNavigationStep() {
        guard state.isNavigating else { return }
        //TODO: Display next navigation step from state.activeRoute and update when reached
    }

    private func displayTripSummary(distance: CLLocationDistance, time: TimeInterval) {
        let summary = """
            Distance Traveled: \(Int(distance))m
            Travel Time: \(formatTripTime(time))
            """

        let summaryAlert = UIAlertController(title: "Trip Summary", message: summary, preferredStyle: .alert)
        summaryAlert.addAction(.init(title: "See Route", style: .cancel) { [weak self] _ in
            self?.startButton.setTitle("Clear", for: .normal)
            self?.startButton.setTitleColor(.green, for: .normal)
            self?.mapView.isUserInteractionEnabled = true
            self?.state.set(.pendingUserClear)
        })
        summaryAlert.addAction(.init(title: "OK", style: .default) { [weak self] _ in
            self?.resetViewState()
        })

        present(summaryAlert, animated: true)
    }

    /// Formats and displays an error message to the user.
    private func displayErrorMessage(for error: LocalizedError) {
        let errorAlert = UIAlertController(title: "Hey there", message: error.errorDescription, preferredStyle: .alert)
        errorAlert.addAction(.init(title: "OK", style: .cancel))

        //Don't override a more important message, such as the trip summary
        if presentedViewController == nil {
            present(errorAlert, animated: true)
        }
    }

    /// Resets the view to an appropriate state for restarting the trip selection process.
    private func resetViewState() {
        mapView.removeOverlays(mapView.overlays)
        mapView.isUserInteractionEnabled = true
        mapView.setUserTrackingMode(.none, animated: false)
        mapView.setCenter(mapView.userLocation.coordinate, animated: true)

        startButton.setTitle("Start", for: .normal)
        startButton.setTitleColor(.blue, for: .normal)
        startButton.isEnabled = false

        //TODO: clear destination pin
        //TODO: Remove navigation steps

        state = State()
    }

    /// Returns the provided time increment formatted for display to the user.
    private func formatTripTime(_ time: TimeInterval) -> String {
        if time < 10 {
            return "0:0\(Int(time))"
        } else if time < 60 {
            return "0:\(Int(time))"
        } else {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            return formatter.string(from: time) ?? "0:00"
        }
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
            case travelStartTime
            case pendingUserClear
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
            case .travelStartTime:
                travelStartDate = Date()
            case .pendingUserClear:
                pendingUserClear = true
            }
        }

        /// Indicates whether the map has zoomed to the user's location at app launch.
        var hasPerformedInitialZoom: Bool {
            State.hasPerformedInitialZoom
        }

        /// The amount of time that has elapsed since the user began navigation.
        var elapsedTravelTime: TimeInterval {
            abs(travelStartDate?.timeIntervalSinceNow ?? 0)
        }

        /// The collection of routes currently displayed on the map. Empty when no routes are displayed.
        private(set) var displayedRoutes: [MKRoute] = []

        /// The route currently selected by the user. Updates when a new route is selected. Nil when no routes are displayed.
        private(set) var activeRoute: MKRoute?

        /// Indicates whether the user has begun navigation of the `activeRoute`.
        private(set) var isNavigating = false

        /// The ongoing travel path of the user during navigation.
        private(set) var userTravelPath: [CLLocationCoordinate2D] = []

        /// Indicates that the user has opted to review their completed route and the view must still be reset
        /// before a new trip can be mapped.
        private(set) var pendingUserClear = false

        // Internal reference to the point in time when navigation began. Used for generating `elapsedTravelTime`.
        private var travelStartDate: Date?

        // Internal static reference for whether the initial app launch zoom has been performed.
        static private var hasPerformedInitialZoom = false
    }

    //MARK: UI Constants

    /// The distance the map should be automatically zoomed when the user is selecting a destination.
    private let defaultMapRegionDistance: CLLocationDistance = 1000

    /// The distance the map should be automatically zoomed when navigation begins.
    /// - Note: Currently unused.
    private let minimumMapRegionDistance: CLLocationDistance = 200

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

        if state.isNavigating, let lastPoint = state.userTravelPath.last {
            let delta = tripCoordinator.calculateDistanceTraveled(on: [lastPoint, userLocation.coordinate])

            //Ignore drift from user location inaccuracy
            //FIXME: Should use CLLocationManager and check it's accuracy value instead of this arbitrary distance alone
            if delta > 15 {
                //FIXME: Draw a single continuous path using a custom MKOverlay
                mapView.addOverlay(MKPolyline(coordinates: [lastPoint, userLocation.coordinate], count: 2))
                state.set(.userTravelPathPoint(userLocation.coordinate))
            }
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
        switch error {
        case is LocalizedError:
            displayErrorMessage(for: error as! LocalizedError)
        default:
            displayErrorMessage(for: TripCoordinator.Error.unknownRoutingError)
        }
    }

    func locationUsageAuthorizationRequired(by locationManager: CLLocationManager, in coordinator: TripCoordinator) {
        locationManager.requestWhenInUseAuthorization()
    }

    func locationUsageUnavailable(in coordinator: TripCoordinator) {
        displayErrorMessage(for: TripCoordinator.Error.userLocationUsageIsUnavailable)
    }
}

//Error messages for display by this view controller
extension TripCoordinator.Error: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unknownRoutingError:
            return "Something went wrong while routing to your destination. Sorry about that. Please try again."
        case .userLocationUsageIsUnavailable:
            return "We need to use your location to provide trip routes and navigation. Please go to Settings to enable access."
        }
    }
}

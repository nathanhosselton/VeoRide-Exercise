import UIKit
import MapKit

final class TripViewController: UIViewController {
    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var startButton: UIButton!

    /// The object which manages the trip calculating capabilities of this controller.
    private let tripCoordinator = TripCoordinator()

    override func viewDidLoad() {
        super.viewDidLoad()
        tripCoordinator.delegate = self
        //TODO: Configure initial user location detection failure handling
    }

    /// Handler for the map view's tap gesture recognizer, used to determine the map location of the user's tap
    /// and kickoff trip routing.
    @IBAction private func onMapTapped(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            let tappedPoint = sender.location(in: mapView)
            let coordinate = mapView.convert(tappedPoint, toCoordinateFrom: mapView)

            print(coordinate)

            //TODO: Resolve location from tapped destination?
            //TODO: Show activity indicator
            //TODO: Determine and display route to tapped destination; remove activity indicator
            //TODO: Enable Start button
        }
    }

    /// Handler for the view's Start button, used for initiating navigation.
    @IBAction private func onStartPressed() {
        print("Start Pressed")

        //TODO: Initiate navigation to tapped destination
        //TODO: Convert to cancel button?
    }

    //MARK: UI Constants

    /// The smallest distance the map should be automatically zoomed.
    private let minimumMapRegionDistance: CLLocationDistance = 1000
}

extension TripViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        mapView.setRegion(.init(center: userLocation.coordinate, latitudinalMeters: 0, longitudinalMeters: minimumMapRegionDistance), animated: true)
    }
}

extension TripViewController: TripCoordinatorDelegate {
    func locationUsageAuthorizationRequired(by locationManager: CLLocationManager, in coordinator: TripCoordinator) {
        locationManager.requestWhenInUseAuthorization()
    }

    func locationUsageUnavailable(in coordinator: TripCoordinator) {
        //TODO: Inform user they must enable location usage in Settings for app functionality
    }
}

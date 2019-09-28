import UIKit
import MapKit

final class TripViewController: UIViewController {
    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var startButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        //TODO: Get user's current location and update map region
    }

    /// Handler for the map view's tap gesture recognizer, used to determine the location of the user's tap.
    @IBAction private func onMapTapped(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            let tappedPoint = sender.location(in: mapView)
            let coordinate = mapView.convert(tappedPoint, toCoordinateFrom: mapView)

            print(coordinate)

            //TODO: Resolve location from tapped destination
            //TODO: Determine and display route to tapped destination
            //TODO: Enable Start button
        }
    }

    /// Handler for the view's Start button, used for initiating navigation.
    @IBAction private func onStartPressed() {
        print("Start Pressed")

        //TODO: Initiate navigation to tapped destination
        //TODO: Convert to cancel button?
    }

}

extension TripViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        print(userLocation)
    }
}

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

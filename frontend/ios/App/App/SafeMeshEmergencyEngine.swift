import Foundation
import CoreLocation
import UIKit

@objc public enum EmergencyState: Int {
    case idle = 0
    case locating
    case activating
    case active
    case locationUnavailable
    case contactsNotConfigured
    case failed
    case ended

    public var stringValue: String {
        switch self {
        case .idle: return "IDLE"
        case .locating: return "LOCATING"
        case .activating: return "ACTIVATING"
        case .active: return "ACTIVE"
        case .locationUnavailable: return "LOCATION_UNAVAILABLE"
        case .contactsNotConfigured: return "CONTACTS_NOT_CONFIGURED"
        case .failed: return "FAILED"
        case .ended: return "ENDED"
        }
    }
}

public enum EmergencyTriggerSource: String {
    case ui = "UI"
    case siri = "SIRI"
    case widget = "WIDGET"
    case wearable = "WEARABLE"
    case hardware = "HARDWARE"
}

public struct SafeMeshIncident: Codable {
    public let incidentId: String
    public let timestamp: Double
    public var latitude: Double?
    public var longitude: Double?
    public var accuracy: Double?
    public let triggerSource: String
    public var state: String
    public var isDemoMode: Bool
}

@objc public class SafeMeshEmergencyEngine: NSObject, CLLocationManagerDelegate {
    @objc public static let shared = SafeMeshEmergencyEngine()

    public static let stateChangedNotification = Notification.Name("SafeMeshEmergencyStateChangedNotification")
    public static let appGroupSuiteName = "group.com.safemesh.app"
    private static let kPersistedIncidentKey = "safemesh_active_incident"
    private static let kEmergencyStateKey = "safemesh_emergency_state"

    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var isLocating = false

    public private(set) var currentState: EmergencyState = .idle {
        didSet {
            persistState()
            NotificationCenter.default.post(
                name: SafeMeshEmergencyEngine.stateChangedNotification,
                object: self,
                userInfo: ["state": currentState.stringValue]
            )
        }
    }

    public private(set) var activeIncident: SafeMeshIncident?

    private var sharedDefaults: UserDefaults {
        if let groupDefaults = UserDefaults(suiteName: SafeMeshEmergencyEngine.appGroupSuiteName) {
            return groupDefaults
        }
        return UserDefaults.standard
    }

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        restorePersistedState()
    }

    // MARK: - Core SOS Activation (Shared Engine)

    public func activateSOS(source: EmergencyTriggerSource, completion: ((Bool) -> Void)? = nil) {
        print("[SafeMeshEmergencyEngine] SOS triggered from source: \(source.rawValue)")

        let incidentId = "INC-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(6))"
        var incident = SafeMeshIncident(
            incidentId: incidentId,
            timestamp: Date().timeIntervalSince1970 * 1000,
            latitude: currentLocation?.coordinate.latitude,
            longitude: currentLocation?.coordinate.longitude,
            accuracy: currentLocation?.horizontalAccuracy,
            triggerSource: source.rawValue,
            state: EmergencyState.activating.stringValue,
            isDemoMode: true
        )

        self.activeIncident = incident
        self.currentState = .activating

        // Request real iPhone location immediately
        requestRealLocation { [weak self] location in
            guard let self = self else { return }
            if let loc = location {
                self.currentLocation = loc
                self.activeIncident?.latitude = loc.coordinate.latitude
                self.activeIncident?.longitude = loc.coordinate.longitude
                self.activeIncident?.accuracy = loc.horizontalAccuracy
                print("[SafeMeshEmergencyEngine] Real location secured: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
            } else {
                print("[SafeMeshEmergencyEngine] Real location unavailable at activation time")
            }

            self.activeIncident?.state = EmergencyState.active.stringValue
            self.currentState = .active
            self.persistState()
            completion?(true)
        }
    }

    public func deactivateSOS() {
        print("[SafeMeshEmergencyEngine] Deactivating SOS")
        currentState = .ended
        activeIncident = nil
        clearPersistedState()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.currentState = .idle
        }
    }

    // MARK: - State Inspection

    @objc public func getCurrentStateName() -> String {
        return currentState.stringValue
    }

    @objc public func getActiveIncidentDictionary() -> [String: Any]? {
        guard let incident = activeIncident else { return nil }
        var dict: [String: Any] = [
            "incidentId": incident.incidentId,
            "timestamp": incident.timestamp,
            "triggerSource": incident.triggerSource,
            "state": currentState.stringValue,
            "isDemoMode": incident.isDemoMode
        ]
        if let lat = incident.latitude, let lon = incident.longitude {
            dict["latitude"] = lat
            dict["longitude"] = lon
        }
        if let acc = incident.accuracy {
            dict["accuracy"] = acc
        }
        return dict
    }

    // MARK: - Location Services

    private var locationCallback: ((CLLocation?) -> Void)?

    private func requestRealLocation(completion: @escaping (CLLocation?) -> Void) {
        let authStatus: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            authStatus = locationManager.authorizationStatus
        } else {
            authStatus = CLLocationManager.authorizationStatus()
        }

        switch authStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            self.locationCallback = completion
            locationManager.requestLocation()
        case .notDetermined:
            // Still report cached location if available, do not block SOS
            completion(currentLocation)
        case .denied, .restricted:
            completion(nil)
        @unknown default:
            completion(nil)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        self.currentLocation = loc
        if let incident = activeIncident {
            activeIncident?.latitude = loc.coordinate.latitude
            activeIncident?.longitude = loc.coordinate.longitude
            activeIncident?.accuracy = loc.horizontalAccuracy
            persistState()
        }
        locationCallback?(loc)
        locationCallback = nil
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[SafeMeshEmergencyEngine] Location manager error: \(error.localizedDescription)")
        locationCallback?(currentLocation)
        locationCallback = nil
    }

    // MARK: - Persistence for App Cold Launch / Siri Background Runs

    private func persistState() {
        let defaults = sharedDefaults
        defaults.set(currentState.stringValue, forKey: SafeMeshEmergencyEngine.kEmergencyStateKey)
        if let incident = activeIncident, let encoded = try? JSONEncoder().encode(incident) {
            defaults.set(encoded, forKey: SafeMeshEmergencyEngine.kPersistedIncidentKey)
        } else {
            defaults.removeObject(forKey: SafeMeshEmergencyEngine.kPersistedIncidentKey)
        }
        defaults.synchronize()
    }

    private func restorePersistedState() {
        let defaults = sharedDefaults
        if let stateStr = defaults.string(forKey: SafeMeshEmergencyEngine.kEmergencyStateKey),
           stateStr == EmergencyState.active.stringValue,
           let data = defaults.data(forKey: SafeMeshEmergencyEngine.kPersistedIncidentKey),
           let incident = try? JSONDecoder().decode(SafeMeshIncident.self, from: data) {
            self.activeIncident = incident
            self.currentState = .active
            print("[SafeMeshEmergencyEngine] Restored active SOS incident from storage: \(incident.incidentId)")
        }
    }

    private func clearPersistedState() {
        let defaults = sharedDefaults
        defaults.removeObject(forKey: SafeMeshEmergencyEngine.kEmergencyStateKey)
        defaults.removeObject(forKey: SafeMeshEmergencyEngine.kPersistedIncidentKey)
        defaults.synchronize()
    }
}

import Foundation
import Capacitor
import CoreLocation
import UserNotifications
import UIKit

@objc(SafeMeshNativePlugin)
public class SafeMeshNativePlugin: CAPPlugin, CAPBridgedPlugin, CLLocationManagerDelegate {
    public let identifier = "SafeMeshNativePlugin"
    public let jsName = "SafeMeshNative"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "getEmergencyState", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "activateSOS", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "deactivateSOS", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPermissionStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "openSettings", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "call112", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "callEmergencyContact", returnType: CAPPluginReturnPromise)
    ]

    private var locationManager: CLLocationManager?

    override public func load() {
        super.load()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEmergencyStateChanged(_:)),
            name: SafeMeshEmergencyEngine.stateChangedNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleEmergencyStateChanged(_ notification: Notification) {
        let state = SafeMeshEmergencyEngine.shared.getCurrentStateName()
        let incident = SafeMeshEmergencyEngine.shared.getActiveIncidentDictionary()
        notifyListeners("emergencyStateChange", data: [
            "state": state,
            "incident": incident as Any
        ])
    }

    @objc func getEmergencyState(_ call: CAPPluginCall) {
        let state = SafeMeshEmergencyEngine.shared.getCurrentStateName()
        let incident = SafeMeshEmergencyEngine.shared.getActiveIncidentDictionary()
        call.resolve([
            "state": state,
            "incident": incident as Any
        ])
    }

    @objc func activateSOS(_ call: CAPPluginCall) {
        let sourceString = call.getString("source") ?? "UI"
        let source: EmergencyTriggerSource
        switch sourceString.uppercased() {
        case "SIRI": source = .siri
        case "WIDGET": source = .widget
        case "WEARABLE": source = .wearable
        case "HARDWARE": source = .hardware
        default: source = .ui
        }

        SafeMeshEmergencyEngine.shared.activateSOS(source: source) { _ in
            call.resolve([
                "success": true,
                "state": SafeMeshEmergencyEngine.shared.getCurrentStateName(),
                "incident": SafeMeshEmergencyEngine.shared.getActiveIncidentDictionary() as Any
            ])
        }
    }

    @objc func deactivateSOS(_ call: CAPPluginCall) {
        SafeMeshEmergencyEngine.shared.deactivateSOS()
        call.resolve([
            "success": true,
            "state": "IDLE"
        ])
    }

    @objc func getPermissionStatus(_ call: CAPPluginCall) {
        if locationManager == nil {
            locationManager = CLLocationManager()
        }

        let locStatus: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            locStatus = locationManager?.authorizationStatus ?? .notDetermined
        } else {
            locStatus = CLLocationManager.authorizationStatus()
        }

        let locString: String
        switch locStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locString = "granted"
        case .denied, .restricted:
            locString = "denied"
        case .notDetermined:
            locString = "prompt"
        @unknown default:
            locString = "unknown"
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let notifString: String
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                notifString = "granted"
            case .denied:
                notifString = "denied"
            case .notDetermined:
                notifString = "prompt"
            @unknown default:
                notifString = "unknown"
            }

            call.resolve([
                "location": locString,
                "notifications": notifString
            ])
        }
    }

    @objc func openSettings(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl, options: [:]) { success in
                    call.resolve(["opened": success])
                }
            } else {
                call.reject("Cannot open iOS Settings")
            }
        }
    }

    @objc func call112(_ call: CAPPluginCall) {
        let isDevMode = call.getBool("isDemoMode") ?? true

        DispatchQueue.main.async {
            // For development safety, do not silently dial real emergency services without confirmation
            if isDevMode {
                // In demo/hackathon mode, resolve safely and provide demo confirmation
                call.resolve([
                    "success": true,
                    "action": "DEMO_SAFE_CONFIRMED",
                    "message": "Demo Safe Mode: 112 emergency dispatch interface verified without live dispatch call."
                ])
                return
            }

            guard let url = URL(string: "tel://112"), UIApplication.shared.canOpenURL(url) else {
                call.reject("Device cannot place phone calls or 112 is unavailable on this device.")
                return
            }

            UIApplication.shared.open(url, options: [:]) { success in
                call.resolve(["success": success])
            }
        }
    }

    @objc func callEmergencyContact(_ call: CAPPluginCall) {
        guard let phone = call.getString("phone")?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty else {
            call.reject("No emergency contact configured. Add an emergency contact first.")
            return
        }

        let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let url = URL(string: "tel://\(cleaned)"), UIApplication.shared.canOpenURL(url) else {
            call.reject("Cannot place call to \(phone). Native phone dialer unavailable.")
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { success in
                call.resolve(["success": success])
            }
        }
    }
}

import Foundation
import AppIntents

@available(iOS 16.0, *)
public struct ActivateSafeMeshIntent: AppIntent {
    public static var title: LocalizedStringResource = "Activate SafeMesh"
    public static var description = IntentDescription("Activates SafeMesh SOS emergency mode and captures current real location.")

    // Open SafeMesh immediately so the Emergency Mode screen is presented
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Trigger the ONE central emergency engine
        SafeMeshEmergencyEngine.shared.activateSOS(source: .siri)

        return .result(dialog: "SafeMesh SOS has been activated. Emergency Mode is opening.")
    }
}

@available(iOS 16.0, *)
public struct SafeMeshShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ActivateSafeMeshIntent(),
            phrases: [
                "Activate \(.applicationName)",
                "Start \(.applicationName)",
                "Activate \(.applicationName) SOS",
                "Trigger \(.applicationName)"
            ],
            shortTitle: "Activate SafeMesh",
            systemImageName: "exclamationmark.shield.fill"
        )
    }
}

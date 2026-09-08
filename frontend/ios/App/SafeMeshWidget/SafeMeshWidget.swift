import WidgetKit
import SwiftUI
import AppIntents

struct SafeMeshWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SafeMeshWidgetEntry {
        SafeMeshWidgetEntry(date: Date(), isEmergencyActive: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SafeMeshWidgetEntry) -> Void) {
        let entry = SafeMeshWidgetEntry(date: Date(), isEmergencyActive: checkEmergencyActive())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SafeMeshWidgetEntry>) -> Void) {
        let entry = SafeMeshWidgetEntry(date: Date(), isEmergencyActive: checkEmergencyActive())
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }

    private func checkEmergencyActive() -> Bool {
        let defaults = UserDefaults(suiteName: "group.com.safemesh.app") ?? UserDefaults.standard
        let state = defaults.string(forKey: "safemesh_emergency_state")
        return state == "ACTIVE" || state == "ACTIVATING"
    }
}

struct SafeMeshWidgetEntry: TimelineEntry {
    let date: Date
    let isEmergencyActive: Bool
}

struct SafeMeshWidgetEntryView: View {
    var entry: SafeMeshWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Off-white / clean light surface background
            Color(red: 0.96, green: 0.97, blue: 0.98)

            VStack(spacing: 10) {
                // Header
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                        Text("SAFE MESH")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                    }
                    Spacer()
                    Circle()
                        .fill(entry.isEmergencyActive ? Color.red : Color(red: 0.2, green: 0.78, blue: 0.35))
                        .frame(width: 6, height: 6)
                }

                Spacer()

                // SOS Core Button
                ZStack {
                    Circle()
                        .fill(
                            entry.isEmergencyActive
                                ? Color.red.opacity(0.2)
                                : Color(red: 0.90, green: 0.18, blue: 0.20).opacity(0.18)
                        )
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.92, green: 0.18, blue: 0.22),
                                    Color(red: 0.75, green: 0.10, blue: 0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.red.opacity(0.35), radius: 6, x: 0, y: 3)

                    Text("SOS")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.0)
                }

                Spacer()

                // Subtitle
                Text(entry.isEmergencyActive ? "EMERGENCY ACTIVE" : "Tap to activate")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(entry.isEmergencyActive ? Color.red : Color(red: 0.45, green: 0.50, blue: 0.58))
            }
            .padding(14)
        }
        .widgetURL(URL(string: "safemesh://sos?source=widget"))
    }
}

@main
struct SafeMeshWidget: Widget {
    let kind: String = "SafeMeshWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SafeMeshWidgetProvider()) { entry in
            SafeMeshWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("SafeMesh SOS")
        .description("Instantly activate SafeMesh emergency SOS mode from your Home Screen.")
        .supportedFamilies([.systemSmall])
    }
}

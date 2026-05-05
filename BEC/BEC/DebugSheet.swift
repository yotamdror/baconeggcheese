import SwiftUI
import CoreLocation

// MARK: - Shake Detection

struct ShakeDetector: UIViewRepresentable {
    let onShake: () -> Void

    final class ShakeView: UIView {
        var onShake: (() -> Void)?
        override var canBecomeFirstResponder: Bool { true }
        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake { onShake?() }
        }
    }

    func makeUIView(context: Context) -> ShakeView {
        let view = ShakeView()
        view.onShake = onShake
        DispatchQueue.main.async { view.becomeFirstResponder() }
        return view
    }

    func updateUIView(_ uiView: ShakeView, context: Context) {
        uiView.onShake = onShake
    }
}

// MARK: - Screen Snapshot

struct ScreenSnapshot {
    let placeName: String
    let walkMins: Int
    let direction: String
    let status: String
}

// MARK: - Debug Sheet

struct DebugSheetView: View {
    let userLocation: CLLocation
    let heading: CLLocationDirection?
    let snapshot: ScreenSnapshot?

    @Environment(\.dismiss) private var dismiss

    private var coord: CLLocationCoordinate2D { userLocation.coordinate }
    private var inManhattan: Bool { LocationManager.isInManhattan(userLocation) }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                copySection
                screenSection
                locationSection
                compassSection
                featureFlagsSection
                appSection
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sections

    private var copySection: some View {
        Section {
            Button("Copy Report") {
                UIPasteboard.general.string = buildReport()
                dismiss()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var screenSection: some View {
        Section("SCREEN") {
            if let s = snapshot {
                row("Place", s.placeName)
                row("Walk time", "\(s.walkMins) min")
                row("Direction", s.direction)
                row("Status", s.status)
            } else {
                Text("Loading…")
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
        }
    }

    private var locationSection: some View {
        Section("LOCATION") {
            row("Coordinates", String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
            row("Accuracy", String(format: "±%.0f m", userLocation.horizontalAccuracy))
            row("GPS fix", Self.timeFmt.string(from: userLocation.timestamp))
            LabeledContent("isInManhattan") {
                Text(inManhattan ? "true" : "false")
                    .monospaced()
                    .foregroundStyle(inManhattan ? .green : .orange)
            }
        }
    }

    private var compassSection: some View {
        Section("COMPASS") {
            if let h = heading {
                row("Heading", String(format: "%.1f°", h))
            } else {
                LabeledContent("Heading") {
                    Text("unavailable").monospaced().foregroundStyle(.secondary)
                }
            }
        }
    }

    private var featureFlagsSection: some View {
        Section("FEATURE FLAGS") {
            row("blockCalculator", FeatureFlags.blockCalculator ? "true" : "false")
        }
    }

    private var appSection: some View {
        Section("APP") {
            row("Version", appVersion)
            row("iOS", UIDevice.current.systemVersion)
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value).monospaced()
        }
    }

    private func buildReport() -> String {
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        let gpsFix = Self.timeFmt.string(from: userLocation.timestamp)
        let headingStr = heading.map { String(format: "%.1f°", $0) } ?? "unavailable"

        let screenBlock: String
        if let s = snapshot {
            screenBlock = """
            Place:     \(s.placeName)
            Walk time: \(s.walkMins) min
            Direction: \(s.direction)
            Status:    \(s.status)
            """
        } else {
            screenBlock = "(loading)"
        }

        return """
        BEC Debug Report
        Captured: \(now)

        --- SCREEN ---
        \(screenBlock)

        --- LOCATION ---
        Coordinates:   \(String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
        Accuracy:      ±\(String(format: "%.0f", userLocation.horizontalAccuracy)) m
        GPS fix:       \(gpsFix)
        isInManhattan: \(inManhattan)

        --- COMPASS ---
        Heading: \(headingStr)

        --- FEATURE FLAGS ---
        blockCalculator: \(FeatureFlags.blockCalculator)

        --- APP ---
        Version: \(appVersion)
        iOS:     \(UIDevice.current.systemVersion)
        """
    }
}

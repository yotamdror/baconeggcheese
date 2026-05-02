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

// MARK: - Debug Sheet

struct DebugSheetView: View {
    let userLocation: CLLocation
    let heading: CLLocationDirection?

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
                locationSection
                compassSection
                directionModeSection
                featureFlagsSection
                appSection
                copySection
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

    private var directionModeSection: some View {
        let mode = inManhattan ? "MANHATTAN GRID" : "STANDARD CARDINAL"
        return Section("DIRECTION MODE: \(mode)") {
            row("N  (0°)",   "\"\(dirLabel(0))\"")
            row("E  (90°)",  "\"\(dirLabel(90))\"")
            row("S  (180°)", "\"\(dirLabel(180))\"")
            row("W  (270°)", "\"\(dirLabel(270))\"")
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

    private var copySection: some View {
        Section {
            Button("Copy Report") {
                UIPasteboard.general.string = buildReport()
                dismiss()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value).monospaced()
        }
    }

    // Mirrors the logic in Place.cardinalDirection — kept local to avoid coupling debug UI to model
    private func dirLabel(_ bearing: Double) -> String {
        if inManhattan {
            let g = (bearing + 30).truncatingRemainder(dividingBy: 360)
            switch g {
            case 315..<360, 0..<45: return "uptown"
            case 45..<135:          return "crosstown"
            case 135..<225:         return "downtown"
            default:                return "crosstown"
            }
        }
        switch bearing {
        case 22.5..<67.5:   return "northeast"
        case 67.5..<112.5:  return "east"
        case 112.5..<157.5: return "southeast"
        case 157.5..<202.5: return "south"
        case 202.5..<247.5: return "southwest"
        case 247.5..<292.5: return "west"
        case 292.5..<337.5: return "northwest"
        default:            return "north"
        }
    }

    private func buildReport() -> String {
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        let gpsFix = Self.timeFmt.string(from: userLocation.timestamp)
        let headingStr = heading.map { String(format: "%.1f°", $0) } ?? "unavailable"
        let mode = inManhattan ? "Manhattan grid" : "standard cardinal"
        let samples = [
            "  N  (0°)   → \"\(dirLabel(0))\"",
            "  E  (90°)  → \"\(dirLabel(90))\"",
            "  S  (180°) → \"\(dirLabel(180))\"",
            "  W  (270°) → \"\(dirLabel(270))\"",
        ].joined(separator: "\n")

        return """
        BEC Debug Report
        Captured: \(now)

        --- LOCATION ---
        Coordinates:   \(String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
        Accuracy:      ±\(String(format: "%.0f", userLocation.horizontalAccuracy)) m
        GPS fix:       \(gpsFix)
        isInManhattan: \(inManhattan)

        --- COMPASS ---
        Heading: \(headingStr)

        --- DIRECTION MODE: \(mode.uppercased()) ---
        \(samples)

        --- FEATURE FLAGS ---
        blockCalculator: \(FeatureFlags.blockCalculator)

        --- APP ---
        Version: \(appVersion)
        iOS:     \(UIDevice.current.systemVersion)
        """
    }
}

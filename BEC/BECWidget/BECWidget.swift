import CoreText
import CoreLocation
import WidgetKit
import SwiftUI

// MARK: - Font registration (runs once per extension process)

private let _fontRegistered: Void = {
    if let url = Bundle.main.url(forResource: "CooperBlack", withExtension: "ttf") {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}()

// MARK: - Entry

struct BECWidgetEntry: TimelineEntry {
    let date: Date
    let category: WidgetCategory
    let placeName: String?
    let walkMinutes: Int?
    let bearing: Double?
    let directionLabel: String?
    let lastUpdated: Date?
    let hasLocation: Bool
}

// MARK: - Provider

struct BECWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BECWidgetEntry {
        BECWidgetEntry(date: .now, category: .bec, placeName: "Murray's Bagels",
                       walkMinutes: 4, bearing: 0, directionLabel: "uptown",
                       lastUpdated: Date(timeIntervalSinceNow: -720), hasLocation: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (BECWidgetEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BECWidgetEntry>) -> Void) {
        // .never: widget only updates when an intent calls reloadTimelines — zero background API calls
        completion(Timeline(entries: [buildEntry()], policy: .never))
    }

    private func buildEntry() -> BECWidgetEntry {
        let category = loadCurrentCategory()
        let storedLocation = loadStoredLocation()
        let cachedPlace = loadCachedPlace(category: category)
        let lastUpdated = loadLastUpdated(category: category)

        var walkMinutes: Int?
        var bearing: Double?
        var directionLabel: String?

        if let place = cachedPlace, let loc = storedLocation {
            walkMinutes  = place.walkingMinutes(from: loc)
            bearing      = place.bearing(from: loc)
            directionLabel = place.cardinalDirection(from: loc)
        }

        return BECWidgetEntry(
            date: .now,
            category: category,
            placeName: cachedPlace?.name,
            walkMinutes: walkMinutes,
            bearing: bearing,
            directionLabel: directionLabel,
            lastUpdated: lastUpdated,
            hasLocation: storedLocation != nil
        )
    }
}

// MARK: - Entry view

struct BECWidgetEntryView: View {
    let entry: BECWidgetEntry
    @Environment(\.widgetFamily) private var family

    init(entry: BECWidgetEntry) {
        self.entry = entry
        _ = _fontRegistered
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumBody
        default:            smallBody
        }
    }

    // MARK: Small

    private var smallBody: some View {
        let fg = entry.category.onAccentColor
        return VStack(spacing: 0) {
            Image(entry.category.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)

            Spacer(minLength: 4)

            if let mins = entry.walkMinutes {
                Text("\(mins)")
                    .font(.custom("Cooper Black", size: 46))
                    .foregroundStyle(fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("MIN WALK")
                    .font(.system(size: 8, weight: .black))
                    .tracking(4)
                    .foregroundStyle(fg.opacity(0.55))
            } else {
                Text(entry.hasLocation ? "–" : "tap ↺")
                    .font(.custom("Cooper Black", size: entry.hasLocation ? 46 : 20))
                    .foregroundStyle(fg.opacity(0.5))
                    .multilineTextAlignment(.center)
                if !entry.hasLocation {
                    Text("open app first")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(fg.opacity(0.4))
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 5) {
                if let b = entry.bearing {
                    WidgetArrowView(bearing: b, color: fg, size: 24)
                }
                Text((entry.directionLabel ?? "").uppercased())
                    .font(.custom("Cooper Black", size: 15))
                    .foregroundStyle(fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 4)

            Text((entry.placeName ?? "").uppercased())
                .font(.system(size: 8, weight: .black))
                .tracking(1.5)
                .foregroundStyle(fg.opacity(0.75))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let updated = entry.lastUpdated {
                Text(relativeTimeString(from: updated))
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(fg.opacity(0.4))
                    .padding(.top, 2)
            }

            Spacer(minLength: 6)

            cycleRow(fg: fg, size: 10)
        }
        .padding(12)
        .containerBackground(entry.category.accentColor, for: .widget)
    }

    // MARK: Medium

    private var mediumBody: some View {
        let fg = entry.category.onAccentColor
        return HStack(alignment: .center, spacing: 0) {
            // Left: icon + name + prev button
            VStack(spacing: 6) {
                Image(entry.category.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)

                Text((entry.placeName ?? "").uppercased())
                    .font(.system(size: 8, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(fg.opacity(0.75))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let updated = entry.lastUpdated {
                    Text(relativeTimeString(from: updated))
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(fg.opacity(0.4))
                }

                Spacer(minLength: 0)

                Button(intent: PrevCategoryIntent()) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(fg.opacity(0.7))
                        .frame(width: 32, height: 24)
                }
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(fg.opacity(0.15))
                .frame(width: 1, height: 80)

            // Right: walk time + arrow + direction + refresh + next button
            VStack(spacing: 4) {
                if let mins = entry.walkMinutes {
                    Text("\(mins)")
                        .font(.custom("Cooper Black", size: 56))
                        .foregroundStyle(fg)
                        .lineLimit(1)
                    Text("MIN WALK")
                        .font(.system(size: 9, weight: .black))
                        .tracking(5)
                        .foregroundStyle(fg.opacity(0.55))
                } else {
                    Text(entry.hasLocation ? "–" : "tap ↺")
                        .font(.custom("Cooper Black", size: entry.hasLocation ? 56 : 22))
                        .foregroundStyle(fg.opacity(0.5))
                    if !entry.hasLocation {
                        Text("open app first")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(fg.opacity(0.4))
                    }
                }

                HStack(spacing: 8) {
                    if let b = entry.bearing {
                        WidgetArrowView(bearing: b, color: fg, size: 28)
                    }
                    Text((entry.directionLabel ?? "").uppercased())
                        .font(.custom("Cooper Black", size: 18))
                        .foregroundStyle(fg)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 16) {
                    Button(intent: RefreshWidgetIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(fg.opacity(0.7))
                            .frame(width: 32, height: 24)
                    }
                    Button(intent: NextCategoryIntent()) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(fg.opacity(0.7))
                            .frame(width: 32, height: 24)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .containerBackground(entry.category.accentColor, for: .widget)
    }

    // MARK: Shared

    @ViewBuilder
    private func cycleRow(fg: Color, size: CGFloat) -> some View {
        HStack {
            Button(intent: PrevCategoryIntent()) {
                Image(systemName: "chevron.left")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(fg.opacity(0.7))
                    .frame(width: 28, height: 20)
            }
            Spacer()
            Button(intent: RefreshWidgetIntent()) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(fg.opacity(0.7))
                    .frame(width: 28, height: 20)
            }
            Spacer()
            Button(intent: NextCategoryIntent()) {
                Image(systemName: "chevron.right")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(fg.opacity(0.7))
                    .frame(width: 28, height: 20)
            }
        }
    }
}

// MARK: - Widget

struct BECWidget: Widget {
    let kind = "BECWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BECWidgetProvider()) { entry in
            BECWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Nearest Bite")
        .description("Your closest BEC, bagel, or pizza slice.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Bundle

@main
struct BECWidgetBundle: WidgetBundle {
    var body: some Widget {
        BECWidget()
    }
}

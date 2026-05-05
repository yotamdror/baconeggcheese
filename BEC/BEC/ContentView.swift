import SwiftUI
import CoreLocation
import UIKit

// MARK: - Design System

private extension Color {
    static let bg        = Color(red: 14/255,  green: 12/255,  blue: 10/255)   // #0e0c0a
    static let drawerBg  = Color(red: 26/255,  green: 23/255,  blue: 20/255)   // #1a1714
    static let textMain  = Color(red: 245/255, green: 244/255, blue: 242/255)  // #f5f4f2
    static let textMuted = Color(red: 107/255, green: 100/255, blue: 96/255)   // #6b6460
    static let textDim   = Color(red: 58/255,  green: 54/255,  blue: 48/255)   // #3a3630
    static let divider   = Color.white.opacity(0.07)
}

// MTA subway line colors — per category
private extension Category {
    var accentColor: Color {
        switch self {
        case .pizza: return Color(red: 238/255, green: 53/255,  blue: 46/255)  // 1/2/3
        case .bagel: return Color(red: 255/255, green: 99/255,  blue: 25/255)  // B/D/F/M
        case .bec:   return Color(red: 0,       green: 102/255, blue: 178/255) // MTA signage blue
        }
    }

    var accentHex: String {
        switch self {
        case .pizza: return "EE352E"
        case .bagel: return "FF6319"
        case .bec:   return "0066B2"
        }
    }
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var tipStore = TipStore()

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            switch locationManager.authorizationStatus {
            case .notDetermined:
                PermissionView { locationManager.requestPermission() }
            case .denied, .restricted:
                NoLocationView()
            default:
                if let loc = locationManager.location {
                    MainView(userLocation: loc, heading: locationManager.heading)
                } else {
                    ProgressView().tint(Color.textMain)
                }
            }
        }
        .animation(.default, value: locationManager.authorizationStatus)
        .environmentObject(tipStore)
    }
}

// MARK: - Permission

struct PermissionView: View {
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image("bec-icon")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .padding(.bottom, 40)
            Text("Only way to find the\nclosest bite is to know\nwhere you are first")
                .font(.system(.title2, design: .serif, weight: .medium))
                .foregroundStyle(Color.textMain)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button(action: onRequest) {
                Text("SHARE MY LOCATION")
                    .font(.system(.subheadline, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Color.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Category.bec.accentColor)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
    }
}

// MARK: - No Location

struct NoLocationView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("NO LOCATION")
                .font(.system(.caption, weight: .black))
                .tracking(4)
                .foregroundStyle(Category.bec.accentColor)
            Text("Only way to find the closest bite is to know where you are first")
                .font(.system(.title3, design: .serif, weight: .medium))
                .foregroundStyle(Color.textMain.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Main

struct MainView: View {
    let userLocation: CLLocation
    let heading: CLLocationDirection?
    @State private var selectedTab = 2
    @State private var showDebugSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            ShakeDetector { showDebugSheet = true }
                .frame(width: 0, height: 0)

            TabView(selection: $selectedTab) {
                ForEach(Array(Category.allCases.enumerated()), id: \.offset) { index, category in
                    CategoryPageView(
                        category: category,
                        userLocation: userLocation,
                        heading: heading
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // 6px dots — active glows in category accent color
            HStack(spacing: 8) {
                ForEach(Array(Category.allCases.enumerated()), id: \.offset) { idx, cat in
                    Circle()
                        .fill(idx == selectedTab ? cat.accentColor : Color.textDim)
                        .frame(width: 6, height: 6)
                        .shadow(
                            color: idx == selectedTab ? cat.accentColor.opacity(0.6) : .clear,
                            radius: 3
                        )
                        .animation(.easeInOut(duration: 0.3), value: selectedTab)
                        .onTapGesture { selectedTab = idx }
                }
            }
            .padding(.top, 8)
        }
        .background(Color.bg)
        .sheet(isPresented: $showDebugSheet) {
            DebugSheetView(userLocation: userLocation, heading: heading)
        }
    }
}

// MARK: - Star Rating

struct StarRatingView: View {
    let rating: Double
    let color: Color

    private var filled: Int { min(5, max(0, Int(rating.rounded()))) }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < filled ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundStyle(i < filled ? color : Color.textDim)
            }
        }
    }
}

// MARK: - Arrow

struct ArrowView: View {
    let bearing: Double
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2

            var shaft = Path()
            shaft.move(to: CGPoint(x: cx, y: size.height * 0.89))
            shaft.addLine(to: CGPoint(x: cx, y: size.height * 0.22))
            ctx.stroke(shaft, with: .color(color),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round))

            var head = Path()
            head.move(to:    CGPoint(x: size.width * 0.27, y: size.height * 0.47))
            head.addLine(to: CGPoint(x: cx,                y: size.height * 0.19))
            head.addLine(to: CGPoint(x: size.width * 0.73, y: size.height * 0.47))
            ctx.stroke(head, with: .color(color),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 64, height: 64)
        .rotationEffect(.degrees(bearing))
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: bearing)
    }
}

// MARK: - Mini Map

struct MiniMapView: View {
    let place: Place
    let userLocation: CLLocation
    let category: Category

    @State private var mapImage: UIImage?

    private var accentColor: Color { category.accentColor }
    private var walkMins: Int { place.walkingMinutes(from: userLocation) }
    private var cardinal: String { place.cardinalDirection(from: userLocation) }

    var body: some View {
        ZStack {
            if let image = mapImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }

            // Gradient fades (match drawer bg)
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.drawerBg, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 36)
                Spacer()
                LinearGradient(colors: [.clear, Color.drawerBg], startPoint: .top, endPoint: .bottom)
                    .frame(height: 36)
            }

        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.07), lineWidth: 1))
        .task(id: place.id) { await fetchMap() }
    }

    // Canvas placeholder shown while the real tile loads
    private var placeholder: some View {
        Canvas { ctx, size in
            let basemap = Color(red: 13/255, green: 15/255, blue: 20/255)
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(basemap))

            let streetColor = Color(red: 28/255, green: 33/255, blue: 48/255)
            for y in stride(from: CGFloat(18), through: size.height, by: 34) {
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(streetColor), lineWidth: 1.5)
            }
            for x in stride(from: CGFloat(28), through: size.width, by: 44) {
                var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(p, with: .color(streetColor), lineWidth: 1.5)
            }
            var route = Path()
            route.move(to: CGPoint(x: size.width * 0.83, y: size.height * 0.78))
            route.addCurve(
                to: CGPoint(x: size.width * 0.50, y: size.height * 0.50),
                control1: CGPoint(x: size.width * 0.83, y: size.height * 0.54),
                control2: CGPoint(x: size.width * 0.64, y: size.height * 0.50)
            )
            ctx.stroke(route, with: .color(accentColor), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    private func fetchMap() async {
        let url = URL(string: "https://zpstulodssnymskvjuya.supabase.co/functions/v1/maps-proxy")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "originLat": userLocation.coordinate.latitude,
            "originLng": userLocation.coordinate.longitude,
            "destLat":   place.location.latitude,
            "destLng":   place.location.longitude,
            "colorHex":  category.accentHex,
        ])

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data) else { return }

        await MainActor.run { mapImage = image }
    }
}

// MARK: - Category Page

struct CategoryPageView: View {
    let category: Category
    let userLocation: CLLocation
    let heading: CLLocationDirection?

    @State private var places: [Place] = []
    @State private var isLoading = true
    @State private var directionsResult: DirectionsResult?
    @State private var selectedPlace: Place?
    @State private var drawerOpen = false

    private var currentPlace: Place? { selectedPlace ?? places.first }

    private let peekH: CGFloat = 96
    private var accentColor: Color { category.accentColor }

    var locationKey: String {
        String(format: "%.3f,%.3f", userLocation.coordinate.latitude, userLocation.coordinate.longitude)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bg.ignoresSafeArea()

            if isLoading {
                loadingView
                    .padding(.bottom, peekH)
            } else if let closest = currentPlace {
                loadedView(closest)
                    .padding(.bottom, peekH)
                    .contentShape(Rectangle())
                    .onTapGesture { if drawerOpen { drawerOpen = false } }

                DrawerView(
                    isOpen: $drawerOpen,
                    place: closest,
                    allPlaces: places,
                    userLocation: userLocation,
                    category: category,
                    accentColor: accentColor,
                    directionsResult: directionsResult,
                    onSelectPlace: selectPlace
                )
                .id("\(category.id)-\(closest.id)")
                .onChange(of: currentPlace?.id) { drawerOpen = false }
            } else {
                noResultsView
                    .padding(.bottom, peekH)
            }
        }
        .task(id: locationKey) { await load() }
    }

    private func displayBearing(for place: Place) -> Double {
        let absolute = place.bearing(from: userLocation)
        guard let h = heading else { return absolute }
        return (absolute - h + 360).truncatingRemainder(dividingBy: 360)
    }

    @ViewBuilder
    private func loadedView(_ place: Place) -> some View {
        let inManhattan = LocationManager.isInManhattan(userLocation)
        let mins = (inManhattan ? directionsResult?.durationMinutes : nil) ?? place.walkingMinutes(from: userLocation)

        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Hero emoji / icon
            Group {
                if category == .bec {
                    Image("bec-icon")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 160, maxHeight: 160)
                } else {
                    Text(category.emoji)
                        .font(.system(size: 130))
                        .lineLimit(1)
                }
            }
            .id(category.id)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            // Arrow + walk time + direction
            HStack(alignment: .center, spacing: 18) {
                ArrowView(bearing: displayBearing(for: place), color: accentColor)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(mins)")
                        .font(.system(size: 96, weight: .bold))
                        .foregroundStyle(accentColor)
                        .kerning(-4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("min walk")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3.5)
                        .foregroundStyle(accentColor.opacity(0.55))
                    Text(place.cardinalDirection(from: userLocation).uppercased())
                        .font(.system(size: 24, weight: .black))
                        .tracking(3)
                        .foregroundStyle(accentColor)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 0)

            // Place name + address
            VStack(spacing: 4) {
                Text(place.name.uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.textMain)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text({
                    let status = place.isOpen ? "OPEN" : "CLOSED"
                    if let label = place.hoursLabel { return "\(status) · \(label)" }
                    return status
                }())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(place.isOpen ? accentColor.opacity(0.75) : Color.textMuted)
                    .lineLimit(1)
                if let rating = place.rating {
                    StarRatingView(rating: rating, color: accentColor)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
    }

    private var loadingView: some View {
        ZStack {
            // Ghost layout — mirrors loadedView's exact spacer structure so the icon
            // lands at the same pixel position when the transition fires.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Group {
                    if category == .bec {
                        Image("bec-icon")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 160, maxHeight: 160)
                    } else {
                        Text(category.emoji)
                            .font(.system(size: 130))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 18) {
                    Canvas { _, _ in }.frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("00")
                            .font(.system(size: 96, weight: .bold))
                            .kerning(-4)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("min walk")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(3.5)
                        Text("N")
                            .font(.system(size: 24, weight: .black))
                            .tracking(3)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 32)
                .hidden()
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    Text("PLACE NAME")
                        .font(.system(size: 18, weight: .bold))
                        .tracking(0.5)
                        .lineLimit(2)
                    Text("OPEN")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                    StarRatingView(rating: 4.0, color: accentColor)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 24)
                .hidden()
                Spacer(minLength: 0)
            }

            Text(category.loadingText)
                .font(.system(.subheadline).italic())
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Text("NOWHERE NEARBY")
                .font(.system(.caption, weight: .black))
                .tracking(4)
                .foregroundStyle(accentColor)
            Text("Nothing within a 15 min walk.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(Color.textMain.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectPlace(_ place: Place) {
        selectedPlace = place
        drawerOpen = false
        directionsResult = nil
        Task {
            let result = await DirectionsService.fetch(origin: userLocation, destination: place)
            await MainActor.run { directionsResult = result }
        }
    }

    private func load() async {
        isLoading = true
        directionsResult = nil
        selectedPlace = nil
        places = (try? await PlacesService.fetch(category: category, location: userLocation)) ?? []
        await MainActor.run {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                isLoading = false
            }
        }
        if let closest = places.first {
            let result = await DirectionsService.fetch(origin: userLocation, destination: closest)
            await MainActor.run { directionsResult = result }
        }
    }
}

// MARK: - Drawer

struct DrawerView: View {
    @Binding var isOpen: Bool
    let place: Place
    let allPlaces: [Place]
    let userLocation: CLLocation
    let category: Category
    let accentColor: Color
    let directionsResult: DirectionsResult?
    let onSelectPlace: (Place) -> Void

    @EnvironmentObject private var tipStore: TipStore

    private let peekH:   CGFloat = 96
    private let drawerH: CGFloat = 510
    private var closedY: CGFloat { drawerH - peekH }

    @State private var targetOffset: CGFloat = 414  // drawerH - peekH
    @State private var reviewPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            Capsule()
                .fill(Color.white.opacity(0.1))
                .frame(width: 36, height: 3)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // Peek row
            Button(action: toggle) {
                HStack {
                    Text(place.formattedAddress ?? "")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.textMuted)
                        .lineLimit(1)
                    Spacer()
                    Text("▲")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textMuted.opacity(0.4))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isOpen)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .padding(.bottom, 4)
            }

            Color.divider.frame(height: 1)

            // Expanded content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    expandedContent
                }
                .padding(.bottom, 40)
            }
            .opacity(isOpen ? 1 : 0)
            .disabled(!isOpen)
        }
        .frame(height: drawerH)
        .background(Color.drawerBg)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // Full-width MTA line bar at top edge
        .overlay(alignment: .top) {
            Rectangle()
                .fill(accentColor)
                .frame(height: 3)
        }
        .shadow(color: .black.opacity(0.5), radius: 40, y: -8)
        .offset(y: targetOffset)
        .onChange(of: isOpen) { open in
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                targetOffset = open ? 0 : closedY
            }
        }
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    let base: CGFloat = isOpen ? 0 : closedY
                    withTransaction(Transaction(animation: nil)) {
                        targetOffset = max(0, min(closedY, base + value.translation.height))
                    }
                }
                .onEnded { value in
                    let dy = value.translation.height
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                        if !isOpen && dy < -60 {
                            isOpen = true; targetOffset = 0
                        } else if isOpen && dy > 60 {
                            isOpen = false; targetOffset = closedY
                        } else {
                            targetOffset = isOpen ? 0 : closedY
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private var expandedContent: some View {
        // Directions label
        Text({
            let inManhattan = LocationManager.isInManhattan(userLocation)
            let mins = (inManhattan ? directionsResult?.durationMinutes : nil) ?? place.walkingMinutes(from: userLocation)
            let fallback = "\(mins) min walk · \(place.cardinalDirection(from: userLocation))"
            if FeatureFlags.blockCalculator && inManhattan,
               let desc = directionsResult?.blockDescription, !desc.isEmpty {
                return desc
            }
            return fallback
        }())
            .font(.system(size: 18, weight: .black))
            .tracking(0.5)
            .foregroundStyle(accentColor)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 10)

        // Mini map — tap to navigate
        Button(action: navigate) {
            MiniMapView(
                place: place,
                userLocation: userLocation,
                category: category
            )
            .padding(.horizontal, 24)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)

        // Reviews
        let allReviews = place.reviews ?? (place.highlightedReview.map { [$0] } ?? [])
        if !allReviews.isEmpty {
            sectionHeader("Word on the street")

            let review = allReviews[min(reviewPage, allReviews.count - 1)]
            VStack(alignment: .leading, spacing: 5) {
                Text("\u{201C}\(review.text)\u{201D}")
                    .font(.system(size: 13).italic())
                    .foregroundStyle(Color.textMuted)
                    .lineSpacing(4)
                Text("— \(review.author.uppercased())")
                    .font(.system(size: 10, weight: .regular))
                    .tracking(2)
                    .foregroundStyle(Color.textDim)

                if allReviews.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<allReviews.count, id: \.self) { i in
                            Circle()
                                .fill(i == reviewPage ? accentColor : Color.textDim)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if value.translation.width < 0 {
                                reviewPage = min(reviewPage + 1, allReviews.count - 1)
                            } else {
                                reviewPage = max(reviewPage - 1, 0)
                            }
                        }
                    }
            )
            .onChange(of: place.id) { reviewPage = 0 }
        }

        // Inline more options
        let otherPlaces = allPlaces.filter { $0.id != place.id }.prefix(4)
        if !otherPlaces.isEmpty {
            sectionHeader("More \(category.moreLabel) nearby")
            ForEach(Array(otherPlaces)) { other in
                Button(action: { onSelectPlace(other) }) {
                    HStack(alignment: .center, spacing: 12) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(other.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.textMain)
                                .lineLimit(1)
                            if let addr = other.formattedAddress {
                                Text(addr)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.textMuted)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text("\(other.walkingMinutes(from: userLocation))")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(accentColor)
                            .kerning(-1)
                        Text("min")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(accentColor.opacity(0.55))
                            .textCase(.uppercase)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                Color.divider.frame(height: 1)
            }
        }

        settingsSection
    }

    @ViewBuilder
    private func sectionHeader(_ label: String) -> some View {
        HStack(spacing: 10) {
            Color.divider.frame(height: 1)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(3)
                .foregroundStyle(Color.textDim)
                .fixedSize()
            Color.divider.frame(height: 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var settingsSection: some View {
        Color.divider.frame(height: 1)

        settingRow("💬", "Feedback",        "Complaints filed in order of spiciness.",
                   bg: Color(red: 232/255, green: 93/255, blue: 4/255).opacity(0.1),
                   action: openFeedback)
        settingRow(
            "☕",
            tipStore.purchased ? "Thank you ☕" : "Buy me a coffee",
            tipStore.purchased ? "You're the best. Really." :
                tipStore.isPurchasing ? "Opening…" : "Support the developer. Optional but appreciated.",
            bg: Color(red: 212/255, green: 43/255, blue: 39/255).opacity(0.1),
            action: tipStore.purchased || tipStore.isPurchasing ? nil : { Task { await tipStore.purchase() } }
        )
    }

    private func settingRow(_ icon: String, _ label: String, _ sub: String, bg: Color, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 0) {
            Button(action: { action?() }) {
                HStack(spacing: 14) {
                    Text(icon)
                        .font(.system(size: 16))
                        .frame(width: 34, height: 34)
                        .background(bg)
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(0.1)
                            .foregroundStyle(Color.textMain)
                        Text(sub)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textMuted)
                    }
                    Spacer()
                    Text("›")
                        .font(.system(size: 14))
                        .foregroundStyle(action != nil ? Color.textMuted.opacity(0.3) : .clear)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .disabled(action == nil)
            Color.divider.frame(height: 1)
        }
    }

    private func openFeedback() {
        let address = "yotamedror@gmail.com"
        let subject = "BEC App Feedback".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(address)?subject=\(subject)") {
            UIApplication.shared.open(url)
        }
    }

    private func toggle() {
        isOpen.toggle()
    }

    private func navigate() {
        let lat = place.location.latitude
        let lng = place.location.longitude
        let q = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let googleURL = URL(string: "comgooglemaps://?q=\(q)&center=\(lat),\(lng)")!
        let appleURL  = URL(string: "maps://?ll=\(lat),\(lng)&q=\(q)")!
        if UIApplication.shared.canOpenURL(googleURL) {
            UIApplication.shared.open(googleURL)
        } else {
            UIApplication.shared.open(appleURL)
        }
    }
}

// MARK: - Top Five — MTA timetable style

struct TopFiveView: View {
    let places: [Place]
    let userLocation: CLLocation
    let category: Category
    let onSelectPlace: (Place) -> Void
    @Environment(\.dismiss) private var dismiss

    private var accentColor: Color { category.accentColor }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                List(Array(places.prefix(5))) { place in
                    Button(action: { onSelectPlace(place) }) {
                        HStack(alignment: .center, spacing: 12) {
                            // MTA line dot
                            Circle()
                                .fill(accentColor)
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .tracking(0.1)
                                    .foregroundStyle(Color.textMain)
                                    .lineLimit(1)
                                if let addr = place.formattedAddress {
                                    Text(addr)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.textMuted)
                                        .lineLimit(1)
                                }
                                if let rating = place.rating {
                                    StarRatingView(rating: rating, color: accentColor)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 0) {
                                Text("\(place.walkingMinutes(from: userLocation))")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(accentColor)
                                    .kerning(-1)
                                Text("min")
                                    .font(.system(size: 8, weight: .bold))
                                    .tracking(2.5)
                                    .foregroundStyle(accentColor.opacity(0.55))
                                    .textCase(.uppercase)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Color.bg)
                    .listRowSeparatorTint(Color.white.opacity(0.07))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("More options nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(accentColor)
                }
            }
        }
    }

}

#Preview {
    ContentView()
}

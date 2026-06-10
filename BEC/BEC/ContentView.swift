import SwiftUI
import CoreLocation
import UIKit

// MARK: - Design System

extension Color {
    static let bg        = Color(red: 14/255,  green: 12/255,  blue: 10/255)   // #0e0c0a
    static let drawerBg  = Color(red: 26/255,  green: 23/255,  blue: 20/255)   // #1a1714
    static let textMain  = Color(red: 245/255, green: 244/255, blue: 242/255)  // #f5f4f2
    static let textMuted = Color(red: 107/255, green: 100/255, blue: 96/255)   // #6b6460
    static let textDim   = Color(red: 58/255,  green: 54/255,  blue: 48/255)   // #3a3630
    static let divider   = Color.white.opacity(0.07)
}

// MTA subway line colors — per category
extension Category {
    var accentColor: Color {
        switch self {
        case .bec:   return Color(red: 0,       green: 102/255, blue: 178/255) // MTA signage blue
        case .bagel: return Color.white
        case .pizza: return Color(red: 255/255, green: 102/255, blue: 0/255)   // FF6600
        }
    }

    var accentHex: String {
        switch self {
        case .bec:   return "0066B2"
        case .bagel: return "FFFFFF"
        case .pizza: return "FF6600"
        }
    }

    // Text/icon color to use on top of accentColor background
    var onAccentColor: Color {
        switch self {
        case .bec:   return .white
        case .bagel: return .black
        case .pizza: return .white
        }
    }

    var iconMaxSize: CGFloat { 300 }
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var tipStore = TipStore()
    @AppStorage("hasSeenAbout") private var hasSeenAbout = false
    @AppStorage("hasSeenOutsideNYCWarning") private var hasSeenOutsideNYCWarning = false
    // Set when the user picks a location by hand (Location Services unavailable).
    @State private var manualLocation: CLLocation?
    @State private var showManualEntry = false

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            if !hasSeenAbout {
                AboutView(onContinue: {
                    hasSeenAbout = true
                    locationManager.requestPermission()
                })
            } else if let manual = manualLocation {
                // Manual location has no device heading — fall back to absolute bearings.
                mainView(for: manual, heading: nil)
            } else {
                switch locationManager.authorizationStatus {
                case .notDetermined:
                    // If Location Services are off system-wide, requestWhenInUseAuthorization()
                    // never prompts and this status can stay .notDetermined forever — give the
                    // same GPS-timeout escape hatch to manual entry so the app isn't a dead end.
                    GPSWaitingView(onEnterManually: { showManualEntry = true })
                case .denied, .restricted:
                    noLocationView
                default:
                    if let loc = locationManager.location {
                        mainView(for: loc, heading: locationManager.heading)
                    } else {
                        GPSWaitingView(onEnterManually: { showManualEntry = true })
                    }
                }
            }
        }
        .animation(.default, value: locationManager.authorizationStatus)
        .environmentObject(tipStore)
        .fullScreenCover(isPresented: $showManualEntry) {
            ManualLocationView(onPick: { loc in
                manualLocation = loc
                showManualEntry = false
            })
        }
    }

    @ViewBuilder
    private func mainView(for loc: CLLocation, heading: CLLocationDirection?) -> some View {
        if !hasSeenOutsideNYCWarning && !LocationManager.isInManhattan(loc) {
            OutsideNYCView(onContinue: { hasSeenOutsideNYCWarning = true })
        } else {
            MainView(userLocation: loc, heading: heading)
        }
    }

    // Shown when location is denied/restricted — Settings as primary, manual entry as fallback.
    private var noLocationView: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("LOCATION OFF")
                .font(.custom("Cooper Black", size: 12))
                .tracking(4)
                .foregroundStyle(Category.bec.accentColor)
                .padding(.bottom, 16)
            Text("Enable location so we can find the closest bite")
                .font(.custom("Cooper Black", size: 20))
                .foregroundStyle(Color.textMain.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button(action: {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }) {
                Text("OPEN SETTINGS")
                    .font(.system(.subheadline, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Color.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Category.bec.accentColor)
            }
            .padding(.horizontal, 24)
            Button(action: { showManualEntry = true }) {
                Text("Enter address manually")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textMuted)
                    .underline()
                    .padding(.vertical, 16)
            }
            .padding(.bottom, 36)
        }
    }
}

// Spinner while GPS resolves — reveals "Enter address manually" after 6 s if still stuck.
private struct GPSWaitingView: View {
    let onEnterManually: () -> Void
    @State private var showEscapeHatch = false

    var body: some View {
        VStack(spacing: 28) {
            ProgressView().tint(Color.textMain)
            if showEscapeHatch {
                Button(action: onEnterManually) {
                    Text("Enter address manually")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textMuted)
                        .underline()
                }
                .transition(.opacity)
            }
        }
        .animation(.default, value: showEscapeHatch)
        .task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            showEscapeHatch = true
        }
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
                .frame(width: 220, height: 220)
                .padding(.bottom, 40)
            Text("Only way to find the\nclosest bite is to know\nwhere you are first")
                .font(.custom("Cooper Black", size: 22))
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

// MARK: - Main

struct MainView: View {
    let userLocation: CLLocation
    let heading: CLLocationDirection?
    // Extended circular array: [pizza(wrap), bec, bagel, pizza, bec(wrap)]
    // Real pages at indices 1-3; wraps at 0 and 4 snap back silently.
    private let circularCategories: [Category] = [.pizza, .bec, .bagel, .pizza, .bec]
    @State private var selectedTab = 1  // Start on bec
    #if DEBUG
    @State private var showDebugSheet = false
    @State private var screenSnapshots: [Category: ScreenSnapshot] = [:]
    #endif

    // Maps extended tab index to dot index (0=bec, 1=bagel, 2=pizza)
    private var dotIndex: Int {
        switch selectedTab {
        case 0: return 2
        case 4: return 0
        default: return selectedTab - 1
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            #if DEBUG
            ShakeDetector { showDebugSheet = true }
                .frame(width: 0, height: 0)
            #endif

            TabView(selection: $selectedTab) {
                ForEach(Array(circularCategories.enumerated()), id: \.offset) { index, category in
                    CategoryPageView(
                        category: category,
                        userLocation: userLocation,
                        heading: heading,
                        onSnapshot: { snap in
                            #if DEBUG
                            screenSnapshots[category] = snap
                            #endif
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .onChange(of: selectedTab) {
                if selectedTab == 0 {
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { selectedTab = 3 }
                } else if selectedTab == 4 {
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { selectedTab = 1 }
                }
            }

            // 6px dots
            HStack(spacing: 8) {
                ForEach(Array(Category.allCases.enumerated()), id: \.offset) { idx, cat in
                    Circle()
                        .fill(idx == dotIndex ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .shadow(
                            color: idx == dotIndex ? Color.white.opacity(0.5) : .clear,
                            radius: 3
                        )
                        .animation(.easeInOut(duration: 0.3), value: selectedTab)
                        .onTapGesture { selectedTab = idx + 1 }
                }
            }
            .padding(.top, 8)
        }
        .background(Color.bg)
        #if DEBUG
        .sheet(isPresented: $showDebugSheet) {
            DebugSheetView(userLocation: userLocation, heading: heading, snapshot: screenSnapshots[circularCategories[selectedTab]])
        }
        #endif
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
        .animation(.spring(response: 0.55, dampingFraction: 0.42), value: bearing)
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
    let onSnapshot: (ScreenSnapshot) -> Void

    @State private var places: [Place] = []
    @State private var isLoading = true
    @State private var isLoadingDirections = false
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
            accentColor.ignoresSafeArea()

            if isLoading {
                loadingView
                    .padding(.bottom, peekH)
                skeletonDrawer
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
                EmptyDrawerView(category: category, accentColor: accentColor)
            }
        }
        .task(id: locationKey) { await load() }
        .onChange(of: currentPlace?.id) { fireSnapshot() }
        .onChange(of: directionsResult?.durationMinutes) { fireSnapshot() }
    }

    private func displayBearing(for place: Place) -> Double {
        let absolute = place.bearing(from: userLocation)
        guard let h = heading else { return absolute }
        return (absolute - h + 360).truncatingRemainder(dividingBy: 360)
    }

    @ViewBuilder
    private func loadedView(_ place: Place) -> some View {
        let inManhattan = LocationManager.isInManhattan(userLocation)
        let mins: Int? = {
            if !inManhattan { return place.walkingMinutes(from: userLocation) }
            if isLoadingDirections { return nil }
            return directionsResult?.durationMinutes ?? place.walkingMinutes(from: userLocation)
        }()
        let direction = place.cardinalDirection(from: userLocation).uppercased()
        let status: String = {
            let s = place.isOpen ? "OPEN" : "CLOSED"
            if let label = place.hoursLabel { return "\(s) · \(label)" }
            return s
        }()

        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Hero image
            Group {
                Image(category.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: category.iconMaxSize, maxHeight: category.iconMaxSize)
            }
            .id(category.id)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            // Walk time — owns the screen
            Text(mins.map { "\($0)" } ?? "–")
                .font(.custom("Cooper Black", size: 148))
                .foregroundStyle(category.onAccentColor)
                .kerning(-6)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            Text("MIN WALK")
                .font(.system(size: 11, weight: .black))
                .tracking(6)
                .foregroundStyle(category.onAccentColor.opacity(0.55))
                .padding(.top, 4)

            // Arrow + direction centered together
            HStack(spacing: 12) {
                ArrowView(bearing: displayBearing(for: place), color: category.onAccentColor)
                Text(direction)
                    .font(.custom("Cooper Black", size: 32))
                    .tracking(3)
                    .foregroundStyle(category.onAccentColor)
            }
            .padding(.top, 10)

            Spacer(minLength: 0)

            // Place name + status — pinned near drawer
            VStack(spacing: 3) {
                Text(place.name.uppercased())
                    .font(.system(size: 13, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(category.onAccentColor.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(status)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(place.isOpen ? category.onAccentColor.opacity(0.6) : category.onAccentColor.opacity(0.35))
                    .lineLimit(1)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
    }

    private var skeletonDrawer: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(accentColor.opacity(0.5))
                .frame(width: 36, height: 3)
                .padding(.top, 10)
                .padding(.bottom, 6)
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 140, height: 9)
                Spacer()
                Text("▲")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textMuted.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .padding(.bottom, 4)
            Spacer()
        }
        .frame(height: 510)
        .background(Color.drawerBg)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 40, y: -8)
        .offset(y: 510 - 96)
    }

    private var loadingView: some View {
        ZStack {
            // Ghost layout mirrors loadedView structure so emoji lands at the same position on transition.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Group {
                    Image(category.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: category.iconMaxSize, maxHeight: category.iconMaxSize)
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                Text("00")
                    .font(.custom("Cooper Black", size: 148))
                    .kerning(-6)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("MIN WALK")
                    .font(.system(size: 11, weight: .black))
                    .tracking(6)
                    .padding(.top, 4)
                Text("N")
                    .font(.custom("Cooper Black", size: 32))
                    .tracking(3)
                    .padding(.top, 10)
                Spacer(minLength: 0)
                VStack(spacing: 3) {
                    Text("PLACE NAME")
                        .font(.system(size: 13, weight: .black))
                        .tracking(1.5)
                        .lineLimit(2)
                    Text("OPEN")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.5)
                }
                .padding(.horizontal, 32)
                Spacer(minLength: 0)
            }
            .hidden()

            Text(category.loadingText)
                .font(.system(.subheadline).italic())
                .foregroundStyle(category.onAccentColor.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Food icon — dimmed to signal nothing's open right now
            Image(category.iconName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: category.iconMaxSize, maxHeight: category.iconMaxSize)
                .grayscale(1)
                .opacity(0.35)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Text("NOTHING OPEN")
                    .font(.custom("Cooper Black", size: 40))
                    .tracking(1)
                    .foregroundStyle(category.onAccentColor)
                    .multilineTextAlignment(.center)
                Text(category.noResultsText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(category.onAccentColor.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fireSnapshot() {
        guard let place = currentPlace else { return }
        let mins = directionsResult?.durationMinutes ?? place.walkingMinutes(from: userLocation)
        let direction = place.cardinalDirection(from: userLocation).uppercased()
        let status: String = {
            let s = place.isOpen ? "OPEN" : "CLOSED"
            if let label = place.hoursLabel { return "\(s) · \(label)" }
            return s
        }()
        onSnapshot(ScreenSnapshot(placeName: place.name.uppercased(), walkMins: mins, direction: direction, status: status))
    }

    private func selectPlace(_ place: Place) {
        selectedPlace = place
        drawerOpen = false
        directionsResult = nil
        isLoadingDirections = true
        Task {
            let result = await DirectionsService.fetch(origin: userLocation, destination: place)
            await MainActor.run {
                directionsResult = result
                isLoadingDirections = false
            }
        }
    }

    private func load() async {
        isLoading = true
        directionsResult = nil
        selectedPlace = nil
        places = (try? await PlacesService.fetch(category: category, location: userLocation)) ?? []
        if let closest = places.first {
            let result = await DirectionsService.fetch(origin: userLocation, destination: closest)
            await MainActor.run { directionsResult = result }
        }
        await MainActor.run {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                isLoading = false
            }
            fireSnapshot()
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

    @State private var targetOffset: CGFloat
    @State private var reviewPage = 0
    @State private var showAbout = false
    @State private var showFeedback = false

    init(
        isOpen: Binding<Bool>,
        place: Place,
        allPlaces: [Place],
        userLocation: CLLocation,
        category: Category,
        accentColor: Color,
        directionsResult: DirectionsResult?,
        onSelectPlace: @escaping (Place) -> Void,
        startFullyOpen: Bool = false
    ) {
        _isOpen = isOpen
        self.place = place
        self.allPlaces = allPlaces
        self.userLocation = userLocation
        self.category = category
        self.accentColor = accentColor
        self.directionsResult = directionsResult
        self.onSelectPlace = onSelectPlace
        _targetOffset = State(initialValue: startFullyOpen ? 0 : 510 - 96)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            Capsule()
                .fill(accentColor.opacity(0.5))
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
        .shadow(color: .black.opacity(0.5), radius: 40, y: -8)
        .offset(y: targetOffset)
        .sheet(isPresented: $showAbout) {
            AboutView(onContinue: { showAbout = false })
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(onDismiss: { showFeedback = false })
        }
        .onChange(of: isOpen) { open in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
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
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
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
            .font(.custom("Cooper Black", size: 18))
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

        // FEATURE FLAG: reviews hidden — set to true to re-enable
        let reviewsEnabled = false
        if reviewsEnabled {
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

        settingRow("info.circle", "About",          "Built for New York. Works best there too.",
                   action: { showAbout = true })
        settingRow("bubble.left", "Feedback",       "Complaints filed in order of spiciness.",
                   action: { showFeedback = true })
        settingRow("lock", "Privacy Policy",        "What we do (and don't) with your data.",
                   action: openPrivacyPolicy)
        settingRow(
            "cup.and.saucer",
            tipStore.purchased ? "Thank you" : "Pay me",
            tipStore.purchased ? "You're the best. Really." :
                tipStore.isPurchasing ? "Opening…" :
                tipStore.loadFailed ? "Couldn't connect — tap to retry" :
                tipStore.product == nil ? "Loading…" :
                tipStore.purchaseError ?? "Because it would make me happy.",
            action: tipStore.purchased || tipStore.isPurchasing || (tipStore.product == nil && !tipStore.loadFailed)
                ? nil
                : { Task { await tipStore.purchase() } }
        )
    }

    private func settingRow(_ systemImage: String, _ label: String, _ sub: String, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 0) {
            Button(action: { action?() }) {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.06))
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
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
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

    private func openPrivacyPolicy() {
        if let url = URL(string: "https://yotamdror.github.io/bec-privacy/") {
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


// MARK: - Empty Drawer

private struct EmptyDrawerView: View {
    let category: Category
    let accentColor: Color

    private let peekH:   CGFloat = 96
    private let drawerH: CGFloat = 510
    private var closedY: CGFloat { drawerH - peekH }

    @State private var isOpen = false
    @State private var targetOffset: CGFloat = 510 - 96

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(accentColor.opacity(0.5))
                .frame(width: 36, height: 3)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // Peek row
            Button(action: toggle) {
                HStack {
                    Text("No open locations within a 15 min walk")
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
            VStack(spacing: 0) {
                Spacer()
                Text("We couldn't find anywhere open selling \(category.label.lowercased()) right now. Sorry.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: drawerH)
        .background(Color.drawerBg)
        .offset(y: targetOffset)
        .gesture(
            DragGesture()
                .onEnded { value in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                        if value.translation.height < -40 { open() }
                        else if value.translation.height > 40 { close() }
                    }
                }
        )
        .buttonStyle(.plain)
    }

    private func toggle() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
            isOpen ? close() : open()
        }
    }

    private func open()  { isOpen = true;  targetOffset = 0 }
    private func close() { isOpen = false; targetOffset = closedY }
}

// MARK: - Preview Helpers

#if DEBUG
extension CategoryPageView {
    init(category: Category, userLocation: CLLocation, heading: CLLocationDirection?,
         onSnapshot: @escaping (ScreenSnapshot) -> Void, previewPlaces: [Place]) {
        self.category = category
        self.userLocation = userLocation
        self.heading = heading
        self.onSnapshot = onSnapshot
        self._places = State(initialValue: previewPlaces)
        self._isLoading = State(initialValue: false)
        self._directionsResult = State(initialValue: nil)
        self._selectedPlace = State(initialValue: nil)
        self._drawerOpen = State(initialValue: false)
    }
}
#endif

private extension Place {
    static func mock(
        id: String = "preview",
        name: String = "Leo's Bagels",
        address: String = "3 Hanover Square, New York, NY",
        lat: Double = 40.7068,
        lng: Double = -74.0090,
        rating: Double? = 4.7,
        isOpen: Bool = true,
        review: String? = "Best everything bagel in the financial district.",
        reviewAuthor: String = "A. New Yorker"
    ) -> Place {
        let ratingJSON = rating.map { String($0) } ?? "null"
        let reviewJSON = review.map { r in
            "{\"text\": \"\(r)\", \"author\": \"\(reviewAuthor)\"}"
        } ?? "null"
        let json = """
        {
            "id": "\(id)",
            "displayName": {"text": "\(name)"},
            "formattedAddress": "\(address)",
            "location": {"latitude": \(lat), "longitude": \(lng)},
            "rating": \(ratingJSON),
            "currentOpeningHours": {"openNow": \(isOpen)},
            "highlightedReview": \(reviewJSON)
        }
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(Place.self, from: json)
    }
}

private let previewLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)

private let mockBECPlaces: [Place] = [
    .mock(id: "b1", name: "Eisenberg's Sandwich Shop", address: "174 5th Ave", lat: 40.7411, lng: -73.9897, rating: 4.6, review: "The BEC here is a religious experience.", reviewAuthor: "M. Feinberg"),
    .mock(id: "b2", name: "Gem Spa", address: "131 2nd Ave", lat: 40.7264, lng: -73.9842, rating: 4.2, review: nil),
    .mock(id: "b3", name: "Lexington Candy Shop", address: "1226 Lexington Ave", lat: 40.7758, lng: -73.9569, rating: 4.5, review: nil),
]

private let mockPizzaPlaces: [Place] = [
    .mock(id: "p1", name: "Joe's Pizza", address: "7 Carmine St", lat: 40.7303, lng: -74.0023, rating: 4.8, review: "The platonic ideal of a NYC slice.", reviewAuthor: "A. Critic"),
    .mock(id: "p2", name: "Di Fara Pizza", address: "1424 Avenue J", lat: 40.6249, lng: -73.9615, rating: 4.9, review: nil),
    .mock(id: "p3", name: "Lucali", address: "575 Henry St", lat: 40.6791, lng: -73.9987, rating: 4.9, review: nil),
]

private let mockBagelPlaces: [Place] = [
    .mock(id: "bg1", name: "Leo's Bagels", address: "3 Hanover Square", lat: 40.7068, lng: -74.0090, rating: 4.7, review: "Best everything bagel in the financial district.", reviewAuthor: "A. New Yorker"),
    .mock(id: "bg2", name: "Russ & Daughters", address: "179 E Houston St", lat: 40.7223, lng: -73.9868, rating: 4.8, review: nil),
    .mock(id: "bg3", name: "Ess-a-Bagel", address: "831 3rd Ave", lat: 40.7548, lng: -73.9692, rating: 4.6, review: nil),
]

// MARK: - Previews

#Preview("Permission") {
    ZStack {
        Color(red: 14/255, green: 12/255, blue: 10/255).ignoresSafeArea()
        PermissionView {}
    }
}

#if DEBUG
#Preview("BEC – Loaded") {
    CategoryPageView(category: .bec, userLocation: previewLocation, heading: 30, onSnapshot: { _ in }, previewPlaces: mockBECPlaces)
        .environmentObject(TipStore())
}

#Preview("Pizza – Loaded") {
    CategoryPageView(category: .pizza, userLocation: previewLocation, heading: 30, onSnapshot: { _ in }, previewPlaces: mockPizzaPlaces)
        .environmentObject(TipStore())
}

#Preview("Bagel – Loaded") {
    CategoryPageView(category: .bagel, userLocation: previewLocation, heading: 30, onSnapshot: { _ in }, previewPlaces: mockBagelPlaces)
        .environmentObject(TipStore())
}
#endif

#if DEBUG
#Preview("Drawer – BEC Open") {
    ZStack(alignment: .bottom) {
        Color(red: 14/255, green: 12/255, blue: 10/255).ignoresSafeArea()
        DrawerView(
            isOpen: .constant(true),
            place: mockBECPlaces[0],
            allPlaces: mockBECPlaces,
            userLocation: previewLocation,
            category: .bec,
            accentColor: Color(red: 0, green: 102/255, blue: 178/255),
            directionsResult: nil,
            onSelectPlace: { _ in },
            startFullyOpen: true
        )
        .environmentObject(TipStore())
    }
}

#Preview("Drawer – Pizza Open") {
    ZStack(alignment: .bottom) {
        Color(red: 14/255, green: 12/255, blue: 10/255).ignoresSafeArea()
        DrawerView(
            isOpen: .constant(true),
            place: mockPizzaPlaces[0],
            allPlaces: mockPizzaPlaces,
            userLocation: previewLocation,
            category: .pizza,
            accentColor: Color(red: 238/255, green: 53/255, blue: 46/255),
            directionsResult: nil,
            onSelectPlace: { _ in },
            startFullyOpen: true
        )
        .environmentObject(TipStore())
    }
}

#Preview("Drawer – Bagel Open") {
    ZStack(alignment: .bottom) {
        Color(red: 14/255, green: 12/255, blue: 10/255).ignoresSafeArea()
        DrawerView(
            isOpen: .constant(true),
            place: mockBagelPlaces[0],
            allPlaces: mockBagelPlaces,
            userLocation: previewLocation,
            category: .bagel,
            accentColor: Color(red: 1, green: 99/255, blue: 25/255),
            directionsResult: nil,
            onSelectPlace: { _ in },
            startFullyOpen: true
        )
        .environmentObject(TipStore())
    }
}
#endif

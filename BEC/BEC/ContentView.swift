import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        Group {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                PermissionView { locationManager.requestPermission() }
            case .denied, .restricted:
                MessageView(text: "Only way to find the closest bite is to know where you are first")
            default:
                if let loc = locationManager.location {
                    MainView(userLocation: loc)
                } else {
                    ProgressView("Finding you...")
                }
            }
        }
        .animation(.default, value: locationManager.authorizationStatus)
    }
}

// MARK: - Permission screen

struct PermissionView: View {
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Text("🥓🥚🧀")
                .font(.system(size: 80))
            Text("Only way to find the closest bite is to know where you are first")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Share My Location", action: onRequest)
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Generic message (denied location, no results)

struct MessageView: View {
    let text: String

    var body: some View {
        VStack(spacing: 24) {
            Text("🗺️")
                .font(.system(size: 64))
            Text(text)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Main swipe view (3 categories)

struct MainView: View {
    let userLocation: CLLocation
    @State private var selectedTab = 2 // Start on BEC

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Array(Category.allCases.enumerated()), id: \.offset) { index, category in
                CategoryPageView(category: category, userLocation: userLocation)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .ignoresSafeArea()
    }
}

// MARK: - Per-category page

struct CategoryPageView: View {
    let category: Category
    let userLocation: CLLocation

    @State private var places: [Place] = []
    @State private var isLoading = true
    @State private var showTopFive = false

    var locationKey: String {
        String(format: "%.3f,%.3f", userLocation.coordinate.latitude, userLocation.coordinate.longitude)
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if category == .bec {
                    Image("bec-icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                } else {
                    Text(category.emoji)
                        .font(.system(size: 64))
                }
            }
            .padding(.top, 80)

            Spacer()

            if isLoading {
                ProgressView()
            } else if let closest = places.first {
                PlaceCardView(place: closest, userLocation: userLocation)
                    .padding(.horizontal, 24)
            } else {
                MessageView(text: "Nowhere within a 15 min walk!\nAre you sure you're in NYC?")
            }

            Spacer()

            if places.count > 1 {
                Button("See the other closest options") { showTopFive = true }
                    .padding(.bottom, 48)
            }
        }
        .task(id: locationKey) { await load() }
        .sheet(isPresented: $showTopFive) {
            TopFiveView(places: places, userLocation: userLocation, category: category)
        }
    }

    private func load() async {
        isLoading = true
        places = (try? await PlacesService.fetch(category: category, location: userLocation)) ?? []
        isLoading = false
    }
}

// MARK: - Place card

struct PlaceCardView: View {
    let place: Place
    let userLocation: CLLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(place.name)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)

            if let address = place.formattedAddress {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                Label("~\(place.walkingMinutes(from: userLocation)) min walk", systemImage: "figure.walk")
                if let rating = place.rating {
                    Text(String(format: "%.1f ⭐", rating))
                }
            }
            .font(.headline)

            if let review = place.highlightedReview {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\"\(review.text)\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                    Text("— \(review.author)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 2)
            }

            Button(action: navigate) {
                Label("Navigate", systemImage: "map.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding(20)
        .background(.regularMaterial)
        .cornerRadius(16)
    }

    private func navigate() {
        let lat = place.location.latitude
        let lng = place.location.longitude
        let q = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let googleURL = URL(string: "comgooglemaps://?q=\(q)&center=\(lat),\(lng)")!
        let appleURL = URL(string: "maps://?ll=\(lat),\(lng)&q=\(q)")!

        if UIApplication.shared.canOpenURL(googleURL) {
            UIApplication.shared.open(googleURL)
        } else {
            UIApplication.shared.open(appleURL)
        }
    }
}

// MARK: - Top 5 list

struct TopFiveView: View {
    let places: [Place]
    let userLocation: CLLocation
    let category: Category
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(Array(places.prefix(5))) { place in
                Button(action: { navigate(to: place) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name).font(.headline)
                            if let addr = place.formattedAddress {
                                Text(addr).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("~\(place.walkingMinutes(from: userLocation)) min")
                                .font(.subheadline.bold())
                            if let r = place.rating {
                                Text(String(format: "%.1f ⭐", r)).font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Closest Options \(category.emoji)")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func navigate(to place: Place) {
        let lat = place.location.latitude
        let lng = place.location.longitude
        let q = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let googleURL = URL(string: "comgooglemaps://?q=\(q)&center=\(lat),\(lng)")!
        let appleURL = URL(string: "maps://?ll=\(lat),\(lng)&q=\(q)")!

        if UIApplication.shared.canOpenURL(googleURL) {
            UIApplication.shared.open(googleURL)
        } else {
            UIApplication.shared.open(appleURL)
        }
    }
}

#Preview {
    ContentView()
}

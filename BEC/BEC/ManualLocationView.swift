import SwiftUI
import CoreLocation

// MARK: - Manual Location (fallback when Location Services are unavailable)
// Lets the user search a NYC address or neighborhood so the app stays fully
// functional without device location — required by App Store Guideline 5.1.5.

struct ManualLocationView: View {
    let onPick: (CLLocation) -> Void

    @State private var query = ""
    @State private var results: [GeocodeResult] = []
    @State private var isSearching = false
    @FocusState private var focused: Bool

    private var accent: Color { Category.bec.accentColor }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Text("WHERE ARE YOU")
                    .font(.system(size: 11, weight: .black))
                    .tracking(3)
                    .foregroundStyle(accent)
                    .padding(.top, 72)
                    .padding(.bottom, 16)

                Text("Enter an address,\ncross street, or landmark")
                    .font(.custom("Cooper Black", size: 26))
                    .foregroundStyle(Color.textMain)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textMuted)
                    TextField("", text: $query, prompt: Text("e.g. Times Square, 1 World Trade")
                        .foregroundColor(Color.textMuted.opacity(0.5)))
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textMain)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($focused)
                    if isSearching {
                        ProgressView().tint(Color.textMuted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal, 24)

                // Results
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(results) { result in
                            Button(action: { onPick(result.location) }) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.name.isEmpty ? result.address : result.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.textMain)
                                        .lineLimit(1)
                                    if !result.address.isEmpty {
                                        Text(result.address)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.textMuted)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                            Color.divider.frame(height: 1)
                        }
                    }
                    .padding(.top, 12)
                }

                Spacer(minLength: 0)
            }
        }
        .onAppear { focused = true }
        // Debounced search — re-runs and cancels as the query changes.
        .task(id: query) {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else {
                results = []
                isSearching = false
                return
            }
            isSearching = true
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            let found = (try? await GeocodeService.fetch(query: trimmed)) ?? []
            if Task.isCancelled { return }
            results = found
            isSearching = false
        }
    }
}

// MARK: - Preview

#Preview("Manual Location") {
    ManualLocationView(onPick: { _ in })
}

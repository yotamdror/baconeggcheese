import SwiftUI

// MARK: - About (shown on first launch + accessible from settings)

struct AboutView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()

                Image("bec-icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .padding(.bottom, 32)

                Text("BUILT FOR NEW YORK CITY")
                    .font(.system(size: 11, weight: .black))
                    .tracking(3)
                    .foregroundStyle(Category.bec.accentColor)
                    .padding(.bottom, 16)

                Text("Just get whatever\nis closest.")
                    .font(.custom("Cooper Black", size: 34))
                    .foregroundStyle(Color.textMain)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 14) {
                    aboutLine("People often wonder — where should I get a slice, a bagel, a bacon egg and cheese? You don't think so hard and we keep things simple.")
                    aboutLine("This app was built for and tested in NYC, and will only search for open options within a 15 min walk.")
                    aboutLine("Good luck finding a BEC a 15 min walk away at 2am in Islamabad...")
                    aboutLine("Bing Bong.")
                }
                .padding(.horizontal, 36)

                Spacer()

                Button(action: onContinue) {
                    Text("LET'S GO KNICKS")
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

    private func aboutLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Category.bec.accentColor)
                .frame(width: 3, height: 3)
                .padding(.top, 8)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.textMuted)
                .lineSpacing(3)
        }
    }
}

// MARK: - Outside NYC warning (shown once after location granted if not in Manhattan)

struct OutsideNYCView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()

                Text("YOU'RE NOT IN NYC")
                    .font(.system(size: 11, weight: .black))
                    .tracking(3)
                    .foregroundStyle(Category.bec.accentColor)
                    .padding(.bottom, 20)

                Text("This thing runs on\nManhattan logic.")
                    .font(.custom("Cooper Black", size: 30))
                    .foregroundStyle(Color.textMain)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)

                Text("This app was built specifically for NYC. There probably isn't a place near you to get a bagel at 11pm in Paris, or a bacon egg and cheese in Islamabad,\n\nbut you're welcome to try.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)

                Spacer()

                Button(action: onContinue) {
                    Text("GOT IT, SHOW ME ANYWAY")
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
}

// MARK: - Feedback

struct FeedbackView: View {
    let onDismiss: () -> Void

    @State private var message = ""
    @State private var state: SubmitState = .idle
    @FocusState private var focused: Bool

    private enum SubmitState { case idle, sending, success, failure }

    private static let endpoint = URL(string: "https://zpstulodssnymskvjuya.supabase.co/functions/v1/submit-feedback")!

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()

                Text("WHAT'S ON YOUR MIND")
                    .font(.system(size: 11, weight: .black))
                    .tracking(3)
                    .foregroundStyle(Category.bec.accentColor)
                    .padding(.bottom, 20)

                if state == .success {
                    Text("Got it.\nThanks for the note.")
                        .font(.custom("Cooper Black", size: 28))
                        .foregroundStyle(Color.textMain)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                } else {
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Bugs, ideas, complaints about the egg ratio…")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textMuted.opacity(0.5))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $message)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textMain)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                            .frame(minHeight: 120, maxHeight: 200)
                            .focused($focused)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                    .padding(.horizontal, 24)

                    if state == .failure {
                        Text("Something went wrong. Try again.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 232/255, green: 93/255, blue: 4/255))
                            .padding(.top, 8)
                    }
                }

                Spacer()

                if state == .success {
                    Button(action: onDismiss) {
                        Text("CLOSE")
                            .font(.system(.subheadline, weight: .black))
                            .tracking(2)
                            .foregroundStyle(Color.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Category.bec.accentColor)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 52)
                } else {
                    Button(action: submit) {
                        Group {
                            if state == .sending {
                                ProgressView().tint(Color.bg)
                            } else {
                                Text("SEND IT")
                                    .font(.system(.subheadline, weight: .black))
                                    .tracking(2)
                                    .foregroundStyle(Color.bg)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.textMuted.opacity(0.3) : Category.bec.accentColor)
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state == .sending)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 52)
                }
            }
        }
        .onAppear { focused = true }
    }

    private func submit() {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state = .sending
        focused = false

        Task {
            do {
                var req = URLRequest(url: Self.endpoint)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body = ["message": trimmed, "app_version": appVersion()]
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (_, response) = try await URLSession.shared.data(for: req)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run { state = (200..<300).contains(code) ? .success : .failure }
            } catch {
                await MainActor.run { state = .failure }
            }
        }
    }

    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}

// MARK: - Previews

#Preview("About") {
    AboutView(onContinue: {})
}

#Preview("Outside NYC") {
    OutsideNYCView(onContinue: {})
}

#Preview("Feedback") {
    FeedbackView(onDismiss: {})
}

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

                Text("ONLY IN NEW YORK")
                    .font(.system(size: 11, weight: .black))
                    .tracking(3)
                    .foregroundStyle(Category.bec.accentColor)
                    .padding(.bottom, 16)

                Text("The best is\nthe closest to you.")
                    .font(.custom("Cooper Black", size: 34))
                    .foregroundStyle(Color.textMain)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 14) {
                    aboutLine("People wonder — where do I get a slice, a bagel, a bacon egg and cheese? The answer is usually the closest one to you.")
                    aboutLine("This app was built specifically for NYC.")
                    aboutLine("There probably isn't a bagel at 11pm in Paris, or a bacon egg and cheese in Islamabad.")
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

// MARK: - Previews

#Preview("About") {
    AboutView(onContinue: {})
}

#Preview("Outside NYC") {
    OutsideNYCView(onContinue: {})
}

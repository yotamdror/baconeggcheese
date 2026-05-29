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

                Text("The closest\nslice. Bagel. BEC.")
                    .font(.custom("Cooper Black", size: 34))
                    .foregroundStyle(Color.textMain)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 14) {
                    aboutLine("Built for the Manhattan grid — uptown, downtown, and crosstown.")
                    aboutLine("The compass knows the angle. Your bodega is closer than you think.")
                    aboutLine("Outside NYC? Might be slim pickings. No promises on the BEC in Paris.")
                }
                .padding(.horizontal, 36)

                Spacer()

                Button(action: onContinue) {
                    Text("LET'S GO")
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

                Text("NOT IN NEW YORK")
                    .font(.system(size: 11, weight: .black))
                    .tracking(3)
                    .foregroundStyle(Category.bec.accentColor)
                    .padding(.bottom, 20)

                Text("This app runs on\nManhattan logic.")
                    .font(.custom("Cooper Black", size: 30))
                    .foregroundStyle(Color.textMain)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)

                Text("Uptown. Downtown. Bodegas open at 3am. If you're not in NYC, we can't promise there's a BEC around the corner.\n\nBut you're welcome to look.")
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

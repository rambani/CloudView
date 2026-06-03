import SwiftUI

/// Page 08 — sunset welcome. Once the user enters here, the @AppStorage
/// flag is flipped and ContentView swaps in the real tab bar.
struct FinishedPage: View {
    var onEnter: () -> Void

    @AppStorage("onboarding_username") private var savedUsername: String = ""

    var body: some View {
        ZStack {
            SkyBackdrop(palette: .sunset, cornerRadius: 0)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Circle()
                    .fill(.white.opacity(0.85))
                    .frame(width: 88, height: 88)
                    .overlay(
                        Image(systemName: "heart")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(CV.Color.accentBlue)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

                Text("YOU'RE IN")
                    .font(CV.Font.mono)
                    .foregroundStyle(.black.opacity(0.55))
                    .tracking(2)

                Text("Welcome,")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundStyle(.black)

                Text("@\(savedUsername.isEmpty ? "skywatcher" : savedUsername)")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.black)

                Text("It's 72° and rain rolls in by one. Let's go read the sky.")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundStyle(.black.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.top, 4)

                PrimaryCTA(title: "Enter Cloudoodle", systemImage: "arrow.right", action: onEnter)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            }
            .padding(.bottom, 40)
        }
    }
}

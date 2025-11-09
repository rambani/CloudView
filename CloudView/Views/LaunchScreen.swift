import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.4, green: 0.7, blue: 1.0),  // Sky blue
                    Color(red: 0.6, green: 0.8, blue: 1.0)   // Lighter blue
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // App icon placeholder - will show actual icon when added
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                // App name
                Text("Cloudoodle")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)

                // Tagline
                Text("AI Cloud Drawings")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}

struct LaunchScreen_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreen()
    }
}

import SwiftUI
import UIKit

/// Identifiable wrapper so a share sheet can present from a
/// nil-able `UIImage?` binding. The id is the image's object
/// identity — good enough for "present once per prepared image."
struct SharePayload: Identifiable {
    let image: UIImage
    var id: ObjectIdentifier { ObjectIdentifier(image) }
}

/// UIKit bridge for `UIActivityViewController`. SwiftUI's `ShareLink`
/// is fine for text/URLs, but image sharing from arbitrary callsites
/// is more reliable through the activity controller — it correctly
/// previews the image and supports Messages/Mail/Instagram/etc.
struct ActivityViewSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

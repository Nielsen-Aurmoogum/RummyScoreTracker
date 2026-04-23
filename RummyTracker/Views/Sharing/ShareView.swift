#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

#if canImport(UIKit)
// UIViewControllerRepresentable wrapping UIActivityViewController

struct ShareView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else

// Fallback for non-UIKit platforms so builds succeed.
struct ShareView: View {
    let url: URL
    var body: some View {
        Text("Sharing is not supported on this platform.")
    }
}

#endif


import SafariServices
import SwiftUI

/// A web page shown inside the app (Safari's reader-grade view), so links never throw the person out to the browser.
struct InAppBrowser: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct InAppLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

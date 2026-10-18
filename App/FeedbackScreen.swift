import MessageUI
import SwiftUI
import UIKit

enum SupportContact {
    static let email = "davidpit2008@gmail.com"
}

private struct MailComposer: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([SupportContact.email])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) { self.onFinish() }
        }
    }
}

struct FeedbackScreen: View {
    @State private var message = ""
    @State private var showComposer = false
    @State private var showFallbackError = false
    @FocusState private var focused: Bool

    private var subject: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Shabbat Waker feedback (\(version) build \(build))"
    }

    private var fullBody: String {
        "\(message)\n\n—\niOS \(UIDevice.current.systemVersion)"
    }

    var body: some View {
        Form {
            Section {
                TextEditor(text: $message)
                    .frame(minHeight: 180)
                    .focused($focused)
            } header: {
                Text("Your message")
            } footer: {
                Text("Opens an email to the Shabbat Waker team. Nothing is sent until you press Send in the email.")
            }
            Section {
                Button {
                    send()
                } label: {
                    Label("Send feedback", systemImage: "paperplane.fill")
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Send feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showComposer) {
            MailComposer(subject: subject, body: fullBody) { showComposer = false }
                .ignoresSafeArea()
        }
        .alert("No email account is set up on this iPhone.", isPresented: $showFallbackError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Write to \(SupportContact.email)")
        }
    }

    private func send() {
        focused = false
        if MFMailComposeViewController.canSendMail() {
            showComposer = true
            return
        }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = SupportContact.email
        components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: fullBody)]
        guard let url = components.url else { showFallbackError = true; return }
        UIApplication.shared.open(url) { opened in
            if !opened { showFallbackError = true }
        }
    }
}

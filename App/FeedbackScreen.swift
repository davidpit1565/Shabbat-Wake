import MessageUI
import SwiftUI
import UIKit

enum SupportContact {
    static let email = "davidpit2008@gmail.com"
}

/// Where feedback is sent: a form service that emails the developer, so the person never leaves the app.
/// The access key belongs to the developer's Web3Forms account (it is meant to be public); the subject carries
/// "[Shabbat Waker]" so the messages can be told apart. With no key the screen offers the Mail app instead.
enum FeedbackRelay {
    static let url = URL(string: "https://api.web3forms.com/submit")!
    static let accessKey = ""
    static let maxLength = 500

    enum Outcome { case sent, failed }

    static func send(name: String, email: String, subject: String, message: String) async -> Outcome {
        guard !accessKey.isEmpty else { return .failed }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        var payload: [String: String] = [
            "access_key": accessKey,
            "name": name,
            "subject": "[Shabbat Waker \(version) (\(build))] \(subject)",
            "message": String(message.prefix(maxLength))
        ]
        if !email.isEmpty { payload["email"] = email }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return .failed }
        request.httpBody = body
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return .failed }
            let result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            return (result?["success"] as? Bool) == true ? .sent : .failed
        } catch {
            return .failed
        }
    }
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

/// Name, title, message, then one big Send button at the bottom.
struct FeedbackScreen: View {
    private enum Field { case name, email, title, message }

    @Environment(\.dismiss) private var dismiss
    @AppStorage("feedbackName") private var name = ""
    @State private var email = ""
    @State private var title = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var failed = false
    @State private var sent = false
    @State private var showComposer = false
    @FocusState private var focus: Field?

    private var canSend: Bool {
        !isSending
        && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                field("Your name", text: $name, focus: .name)
                field("Your email (optional, so we can reply)", text: $email, focus: .email, keyboard: .emailAddress)
                field("Title", text: $title, focus: .title)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your message").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    TextEditor(text: $message)
                        .accessibilityLabel(Text("Your message"))
                        .focused($focus, equals: .message)
                        .frame(minHeight: 170)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onChange(of: message) { _, value in
                            if value.count > FeedbackRelay.maxLength { message = String(value.prefix(FeedbackRelay.maxLength)) }
                        }
                    Text("\(message.count)/\(FeedbackRelay.maxLength)")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                if failed {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Could not send right now. Check your connection and try again.")
                            .font(.footnote).foregroundStyle(.red)
                        if MFMailComposeViewController.canSendMail() {
                            Button("Send by email instead") { showComposer = true }
                                .font(.footnote.weight(.semibold))
                        } else if let mailto = URL(string: "mailto:\(SupportContact.email)") {
                            Link("Send by email instead", destination: mailto)
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                send()
            } label: {
                Group {
                    if isSending { ProgressView() } else { Label("Send feedback", systemImage: "paperplane.fill") }
                }
                .font(.headline).frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(!canSend)
            .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Send feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showComposer) {
            MailComposer(subject: "[Shabbat Waker] \(title)", body: "\(message)\n\n—\n\(name)\niOS \(UIDevice.current.systemVersion)") { showComposer = false }
                .ignoresSafeArea()
        }
        .alert("Thank you! Your feedback was sent.", isPresented: $sent) {
            Button("OK") { dismiss() }
        }
    }

    private func field(_ label: LocalizedStringKey, text: Binding<String>, focus target: Field, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            TextField("", text: text)
                .focused($focus, equals: target)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .accessibilityLabel(Text(label))
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func send() {
        focus = nil
        failed = false
        isSending = true
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let outcome = await FeedbackRelay.send(name: trimmedName, email: trimmedEmail, subject: trimmedTitle, message: trimmedMessage)
            isSending = false
            if outcome == .sent { sent = true } else { failed = true }
        }
    }
}

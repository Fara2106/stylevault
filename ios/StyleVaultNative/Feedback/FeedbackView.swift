import OSLog
import StyleVaultCore
import SwiftUI
import UIKit

enum FeedbackFailure: Error {
    case needsAccount, limit, failed
}

protocol FeedbackSending: Sendable {
    func send(kind: String, message: String, info: [String: String], accessToken: String?) async throws
}

/// La funzione `send-feedback` accetta solo chi ha un account e manda il testo per email a Lorenzo.
struct SystemFeedbackSender: FeedbackSending {
    private struct Body: Encodable {
        let kind: String
        let message: String
        let info: [String: String]
    }

    func send(kind: String, message: String, info: [String: String], accessToken: String?) async throws {
        guard let accessToken else { throw FeedbackFailure.needsAccount }
        var request = URLRequest(url: AppConfig.supabaseURL.appendingPathComponent("functions/v1/send-feedback"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(AppConfig.supabaseKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(Body(kind: kind, message: message, info: info))
        let (_, response) = try await URLSession.shared.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return
        case 401: throw FeedbackFailure.needsAccount
        case 429: throw FeedbackFailure.limit
        default: throw FeedbackFailure.failed
        }
    }
}

#if DEBUG
/// Nei test non parte nessuna email: solo con `-SVFakeFeedback`.
struct FakeFeedbackSender: FeedbackSending {
    func send(kind: String, message: String, info: [String: String], accessToken: String?) async throws {}
}
#endif

private struct FeedbackSenderKey: EnvironmentKey {
    static let defaultValue: any FeedbackSending = SystemFeedbackSender()
}

extension EnvironmentValues {
    var feedbackSender: any FeedbackSending {
        get { self[FeedbackSenderKey.self] }
        set { self[FeedbackSenderKey.self] = newValue }
    }
}

/// Difetti e idee. L'avviso sui contenuti sensibili sta in alto e si vede cosa parte con il testo.
struct FeedbackView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.feedbackSender) private var sender
    @Environment(\.dismiss) private var dismiss

    @State private var kind = "bug"
    @State private var message = ""
    @State private var isSending = false
    @State private var isSent = false
    @State private var errorKey: String?

    private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "feedback")

    private var info: [String: String] {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        var system = utsname()
        uname(&system)
        let model = withUnsafeBytes(of: &system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        return FeedbackRules.deviceInfo(appVersion: "\(version) (\(build))",
                                        osVersion: "iOS \(UIDevice.current.systemVersion)", model: model,
                                        language: Locale.current.language.languageCode?.identifier ?? "")
    }

    var body: some View {
        Group {
            if isSent { sent } else { form }
        }
        .background(Palette.bg)
        .navigationTitle(Text("feedback.title"))
        .navigationBarTitleDisplayMode(.inline)
        .tint(Palette.ink)
    }

    private var sent: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle").font(.system(size: 36)).foregroundStyle(Palette.ink)
            Text("feedback.sentTitle").font(.display(24)).foregroundStyle(Palette.ink)
                .accessibilityIdentifier("feedback-sent")
            Text("feedback.sentText").foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            Button { dismiss() } label: { PrimaryLabel("feedback.backToProfile") }.buttonStyle(.plain)
            Button {
                isSent = false
            } label: {
                SecondaryLabel("feedback.sendAnother")
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sensitive: [SensitiveKind] { FeedbackRules.sensitive(in: message) }

    private var form: some View {
        Form {
            Section {
                Text("feedback.intro").foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: 4) {
                    Text("feedback.warningTitle").font(.subheadline.bold()).foregroundStyle(Palette.ink)
                    Text("feedback.warningText").font(.footnote).foregroundStyle(Palette.muted)
                }
                .accessibilityIdentifier("feedback-warning")
            }
            Section("feedback.kindLabel") {
                Picker("feedback.kindLabel", selection: $kind) {
                    Text("feedback.kindBug").tag("bug")
                    Text("feedback.kindIdea").tag("idea")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("feedback-kind")
            }
            Section {
                TextField(LocalizedStringKey(kind == "bug" ? "feedback.messageBugHint" : "feedback.messageIdeaHint"),
                          text: $message, axis: .vertical)
                    .lineLimit(5...12)
                    .accessibilityIdentifier("feedback-message")
            } header: {
                Text(LocalizedStringKey(kind == "bug" ? "feedback.messageBug" : "feedback.messageIdea"))
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "\(message.trimmingCharacters(in: .whitespacesAndNewlines).count)/\(FeedbackRules.maximum)")
                    if !sensitive.isEmpty {
                        Text("native.feedback.sensitive \(sensitive.map { localized($0.labelKey) }.joined(separator: ", "))")
                            .foregroundStyle(Palette.danger)
                            .accessibilityIdentifier("feedback-sensitive")
                    }
                }
            }
            Section {
                ForEach(info.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    if let label = Self.infoKeys[key] {
                        LabeledContent(LocalizedStringKey(label), value: value)
                    }
                }
            } header: {
                Text("feedback.infoTitle")
            } footer: {
                Text("feedback.infoNote")
            }
            Section {
                if let errorKey {
                    Text(LocalizedStringKey(errorKey)).font(.footnote).foregroundStyle(Palette.danger)
                        .accessibilityIdentifier("feedback-error")
                    if errorKey == "native.feedback.needsAccount" {
                        Link(destination: AppConfig.supportMail) { Text("native.feedback.writeEmail").font(.footnote) }
                            .tint(Palette.link)
                            .accessibilityIdentifier("feedback-email")
                    }
                }
                Button(action: send) {
                    Text(isSending ? "feedback.sending" : "feedback.send").frame(maxWidth: .infinity).bold()
                }
                .disabled(isSending || !FeedbackRules.canSend(message))
                .accessibilityIdentifier("feedback-send")
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }

    private static let infoKeys = ["source": "feedback.infoSource", "appVersion": "feedback.infoAppVersion",
                                   "osVersion": "feedback.infoOsVersion", "model": "feedback.infoModel",
                                   "language": "feedback.infoLanguage"]

    private func send() {
        isSending = true
        errorKey = nil
        Task {
            defer { isSending = false }
            do {
                try await sender.send(kind: kind, message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                                      info: info, accessToken: auth.session?.accessToken)
                message = ""
                isSent = true
            } catch FeedbackFailure.needsAccount {
                errorKey = "native.feedback.needsAccount"
            } catch FeedbackFailure.limit {
                errorKey = "feedback.errorLimit"
            } catch {
                logger.error("Segnalazione non inviata: \(error.localizedDescription, privacy: .public)")
                errorKey = "feedback.errorFailed"
            }
        }
    }
}

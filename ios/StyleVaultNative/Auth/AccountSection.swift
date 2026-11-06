import SwiftUI

/// La parte del Profilo con l'account: chi è entrato, uscire, eliminarlo.
struct AccountSection: View {
    @EnvironmentObject private var auth: AuthService
    @AppStorage("auth.skipped") private var skipped = false
    @State private var isDeleteAsked = false
    @State private var errorText: String?
    @State private var busy = false

    var body: some View {
        Section {
            if let user = auth.session?.user {
                if let email = user.email { Text(verbatim: email).foregroundStyle(Palette.muted) }
                Button("auth.logout") { Task { await auth.signOut() } }
                    .disabled(busy)
                    .accessibilityIdentifier("account-logout")
                Button("native.account.delete", role: .destructive) { isDeleteAsked = true }
                    .disabled(busy)
                    .accessibilityIdentifier("account-delete")
            } else {
                Button("native.account.exitToLogin") { skipped = false }
                    .tint(Palette.link)
                    .accessibilityIdentifier("account-login")
            }
        } header: {
            Text("native.account.title")
        } footer: {
            if let errorText { Text(verbatim: errorText).foregroundStyle(Palette.danger) }
        }
        .alert("native.account.delete.title", isPresented: $isDeleteAsked) {
            Button("common.cancel", role: .cancel) {}
            Button("common.delete", role: .destructive, action: deleteAccount)
        } message: {
            Text("native.account.delete.message")
        }
        // L'accento sui tasti dei messaggi non arriva a 4,5:1.
        .tint(Palette.ink)
    }

    private func deleteAccount() {
        busy = true
        errorText = nil
        Task {
            defer { busy = false }
            do {
                try await auth.deleteAccount()
            } catch {
                let kind = AuthErrorKind.from(error)
                errorText = kind == .unreachable ? kind.localizedMessage : String(localized: "auth.errors.delete-failed")
            }
        }
    }
}

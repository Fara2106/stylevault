import SwiftUI

struct LegalDocument: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case privacy, support, deleteAccount
        var id: String { rawValue }
    }

    struct Section: Equatable {
        let heading: String
        let paragraphs: [String]
    }

    let title: String
    let sections: [Section]

    static func document(_ kind: Kind, language: String) -> LegalDocument? {
        (language == "it" ? LegalContent.it : LegalContent.en)[kind]
    }

    /// La lingua in cui l'app si sta mostrando, non quella del telefono.
    static var currentLanguage: String { Bundle.main.preferredLocalizations.first ?? "en" }
}

/// Privacy e supporto stanno dentro l'app: si leggono anche senza rete e dicono ciò che l'app fa davvero.
struct LegalView: View {
    let kind: LegalDocument.Kind

    private var language: String { LegalDocument.currentLanguage }
    private var document: LegalDocument? { LegalDocument.document(kind, language: language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let document {
                    Text(verbatim: document.title)
                        .displayFont(28)
                        .foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("legal-title")
                    Text(verbatim: language == "it" ? LegalContent.itUpdated : LegalContent.enUpdated)
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                    ForEach(document.sections, id: \.heading) { section in
                        if !section.heading.isEmpty {
                            Text(verbatim: section.heading)
                                .font(.headline)
                                .foregroundStyle(Palette.ink)
                                .padding(.top, 8)
                        }
                        ForEach(section.paragraphs, id: \.self) { paragraph in
                            Text(verbatim: paragraph)
                                .font(.subheadline)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if kind == .support {
                        Link(destination: AppConfig.supportMail) { Text("native.feedback.writeEmail") }
                            .tint(Palette.link)
                            .padding(.top, 8)
                            .accessibilityIdentifier("legal-email")
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg)
        .navigationBarTitleDisplayMode(.inline)
    }
}

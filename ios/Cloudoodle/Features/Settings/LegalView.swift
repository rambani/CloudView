import SwiftUI

/// Sheet that renders a bundled legal markdown file. Used as the
/// in-app fallback while `LegalLinks.privacyURL` / `.termsURL` are nil
/// (i.e., before the docs are hosted at a public URL). Once a real URL
/// exists the Settings rows open it in Safari instead and this view
/// stops being instantiated.
struct LegalView: View {
    let title: String
    let resourceName: String   // bundled file basename, no extension

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let attributed = loadMarkdown() {
                        Text(attributed)
                            .font(.system(size: 15))
                            .foregroundStyle(CV.Color.textPrimary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundStyle(CV.Color.textTertiary)
                            Text("Couldn't load \(resourceName).md")
                                .font(CV.Font.ui)
                                .foregroundStyle(CV.Color.textSecondary)
                            Text("Drafts also live in the repo under /docs.")
                                .font(CV.Font.caption)
                                .foregroundStyle(CV.Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(CV.Color.accentBlue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Read the bundled markdown and render it via SwiftUI's built-in
    /// `AttributedString(markdown:)` so links + emphasis + headings
    /// render correctly. Reading + parsing each open is cheap (~50 KB
    /// of text) and keeps the view stateless.
    private func loadMarkdown() -> AttributedString? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "md"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        return try? AttributedString(markdown: raw, options: options)
    }
}

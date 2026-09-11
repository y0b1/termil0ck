import SwiftUI

struct GeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var clipboard: ClipboardController
    @State private var length = 24.0
    @State private var password = CredentialGenerator.password()
    @State private var username = CredentialGenerator.username()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("CREDENTIAL FORGE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(LockTheme.accentForeground)
                Text("Generate locally")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Nothing generated here is saved unless you add it to a credential.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(LockTheme.muted)
            }

            generatorSection(title: "PASSWORD") {
                HStack(spacing: 8) {
                    Text(password)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                        .padding(.horizontal, 10)
                        .background(LockTheme.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Button("Copy") { clipboard.copy(password, label: "Generated password") }
                        .buttonStyle(LockButtonStyle())
                }
                HStack {
                    Text("Length")
                    Slider(value: $length, in: 12...64, step: 1) { editing in
                        if !editing { password = CredentialGenerator.password(length: Int(length)) }
                    }
                    .tint(LockTheme.accentForeground)
                    Text("\(Int(length))")
                        .monospacedDigit()
                        .frame(width: 26, alignment: .trailing)
                    Button("Regenerate") { password = CredentialGenerator.password(length: Int(length)) }
                        .buttonStyle(LockButtonStyle(prominent: true))
                }
                .font(.system(size: 12, design: .rounded))
            }

            generatorSection(title: "USERNAME") {
                HStack(spacing: 8) {
                    Text(username)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                        .padding(.horizontal, 10)
                        .background(LockTheme.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Button("Copy") { clipboard.copy(username, label: "Generated username") }
                        .buttonStyle(LockButtonStyle())
                    Button("Regenerate") { username = CredentialGenerator.username() }
                        .buttonStyle(LockButtonStyle(prominent: true))
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(LockButtonStyle())
            }
        }
        .foregroundStyle(LockTheme.text)
        .padding(22)
        .frame(width: 560)
        .background(LockTheme.surface)
    }

    private func generatorSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(LockTheme.muted)
            content()
        }
        .padding(14)
        .background(LockTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(LockTheme.rule, lineWidth: 1)
        }
    }
}

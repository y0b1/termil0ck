import SwiftUI

struct CredentialEditorView: View {
    let existingItem: VaultItem?
    let onCancel: () -> Void
    let onSave: (VaultItem) -> Void

    @State private var platform: String
    @State private var username: String
    @State private var password: String
    @State private var revealsPassword = false

    init(
        item: VaultItem?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (VaultItem) -> Void
    ) {
        existingItem = item
        self.onCancel = onCancel
        self.onSave = onSave
        _platform = State(initialValue: item?.platform ?? "")
        _username = State(initialValue: item?.username ?? "")
        _password = State(initialValue: item?.password ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(existingItem == nil ? "NEW CREDENTIAL" : "EDIT CREDENTIAL")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(LockTheme.accentForeground)
                Text(existingItem == nil ? "Add a vault entry" : "Update this vault entry")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 13) {
                field("Platform") {
                    TextField("example.com", text: $platform).lockField()
                }
                field("User") {
                    HStack(spacing: 8) {
                        TextField("name or email", text: $username).lockField()
                        Button("Generate") { username = CredentialGenerator.username() }
                            .buttonStyle(LockButtonStyle())
                    }
                }
                field("Password") {
                    HStack(spacing: 8) {
                        Group {
                            if revealsPassword {
                                TextField("password", text: $password)
                            } else {
                                SecureField("password", text: $password)
                            }
                        }
                        .lockField()

                        Button {
                            revealsPassword.toggle()
                        } label: {
                            Image(systemName: revealsPassword ? "eye.slash" : "eye")
                                .frame(width: 14)
                        }
                        .buttonStyle(LockButtonStyle())

                        Button("Generate") { password = CredentialGenerator.password() }
                            .buttonStyle(LockButtonStyle())
                    }
                }
            }

            HStack {
                Button("Cancel") { onCancel() }
                    .buttonStyle(LockButtonStyle())
                Spacer()
                Button(existingItem == nil ? "Add to vault" : "Save changes") {
                    var item = existingItem ?? VaultItem(platform: "", username: "", password: "")
                    item.platform = platform.trimmingCharacters(in: .whitespacesAndNewlines)
                    item.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
                    item.password = password
                    item.updatedAt = Date()
                    onSave(item)
                }
                .buttonStyle(LockButtonStyle(prominent: true))
                .disabled(platform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
            }
        }
        .foregroundStyle(LockTheme.text)
        .padding(22)
        .frame(width: 520)
        .background(LockTheme.surface)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(LockTheme.muted)
            content()
        }
    }
}

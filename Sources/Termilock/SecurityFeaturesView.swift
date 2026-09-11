import SwiftUI

struct SecurityFeaturesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: VaultStore
    @State private var name = ""
    @State private var email = ""
    @State private var waitingDays = 7

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("SECURITY ROADMAP")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(LockTheme.accentForeground)
                    Text("Access & recovery")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }

                capabilityCard(
                    icon: "person.badge.key.fill",
                    title: "Passkeys",
                    status: "EXTENSION REQUIRED",
                    color: LockTheme.warning
                ) {
                    Text("Termilock's local vault is ready for a future credential-provider extension. Storing and using real passkeys requires Apple entitlements, app signing, associated domains, and WebAuthn request handling. This build does not pretend a password string is a passkey.")
                }

                capabilityCard(
                    icon: "person.2.badge.gearshape.fill",
                    title: "Emergency access",
                    status: "LOCAL DESIGNATION",
                    color: LockTheme.accentForeground
                ) {
                    Text("Trusted contacts are encrypted inside this vault. Remote requests, notifications, waiting periods, approval, and key recovery require a reviewed end-to-end encrypted service and are not active yet.")

                    if !store.document.emergencyContacts.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(store.document.emergencyContacts) { contact in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.name)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        Text("\(contact.email) · \(contact.waitingPeriodDays)-day wait")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(LockTheme.muted)
                                    }
                                    Spacer()
                                    Button {
                                        store.deleteContact(contact)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(LockTheme.warning)
                                }
                                .padding(.vertical, 8)
                                if contact.id != store.document.emergencyContacts.last?.id {
                                    Divider().overlay(LockTheme.rule)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Trusted contact name", text: $name).lockField()
                        TextField("Email address", text: $email).lockField()
                        HStack {
                            Stepper("Waiting period: \(waitingDays) days", value: $waitingDays, in: 1...30)
                                .font(.system(size: 12, design: .rounded))
                            Spacer()
                            Button("Designate contact") {
                                store.addContact(EmergencyContact(
                                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                    waitingPeriodDays: waitingDays
                                ))
                                name = ""
                                email = ""
                            }
                            .buttonStyle(LockButtonStyle(prominent: true))
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !email.contains("@"))
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(LockButtonStyle())
                }
            }
            .padding(22)
        }
        .foregroundStyle(LockTheme.text)
        .frame(width: 590, height: 650)
        .background(LockTheme.surface)
    }

    private func capabilityCard<Content: View>(
        icon: String,
        title: String,
        status: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text(status)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
            VStack(alignment: .leading, spacing: 12) { content() }
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(LockTheme.muted)
                .lineSpacing(2)
        }
        .padding(15)
        .background(LockTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(LockTheme.rule, lineWidth: 1)
        }
    }
}

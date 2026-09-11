import SwiftUI

private enum LedgerMetrics {
    static let platform: CGFloat = 160
    static let user: CGFloat = 170
    static let password: CGFloat = 250
    static let action: CGFloat = 100
    static let total = platform + user + password + action
}

struct CredentialTableView: View {
    let items: [VaultItem]
    let onEdit: (VaultItem) -> Void
    let onDelete: (VaultItem) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                LedgerHeader()
                if items.isEmpty {
                    emptyState
                } else {
                    ForEach(items) { item in
                        CredentialRow(item: item, onEdit: onEdit, onDelete: onDelete)
                    }
                }
            }
            .frame(width: LedgerMetrics.total, alignment: .leading)
            .overlay(alignment: .leading) {
                LedgerRules()
                    .allowsHitTesting(false)
            }
        }
        .scrollIndicators(.hidden)
        .background(LockTheme.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(LockTheme.rule, lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 7) {
            Image(systemName: "key.horizontal")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(LockTheme.accentForeground)
            Text("No credentials yet")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text("Add your first entry to start the ledger.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(LockTheme.muted)
        }
        .frame(width: LedgerMetrics.total, height: 180)
    }
}

private struct LedgerRules: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                rule(x: LedgerMetrics.platform, height: proxy.size.height)
                rule(x: LedgerMetrics.platform + LedgerMetrics.user, height: proxy.size.height)
                rule(x: LedgerMetrics.platform + LedgerMetrics.user + LedgerMetrics.password, height: proxy.size.height)
            }
        }
    }

    private func rule(x: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(LockTheme.rule)
            .frame(width: 1, height: height)
            .offset(x: x)
    }
}

private struct LedgerHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            label("PLATFORM", width: LedgerMetrics.platform)
            label("USER", width: LedgerMetrics.user)
            label("PASSWORD", width: LedgerMetrics.password)
            label("COPY", width: LedgerMetrics.action)
        }
        .frame(height: 34)
        .background(LockTheme.raised)
        .overlay(alignment: .bottom) { Rectangle().fill(LockTheme.rule).frame(height: 1) }
    }

    private func label(_ value: String, width: CGFloat) -> some View {
        Text(value)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(LockTheme.muted)
            .padding(.leading, 11)
            .frame(width: width, alignment: .leading)
    }
}

private struct CredentialRow: View {
    @EnvironmentObject private var clipboard: ClipboardController
    let item: VaultItem
    let onEdit: (VaultItem) -> Void
    let onDelete: (VaultItem) -> Void
    @State private var revealsPassword = false
    @State private var confirmsDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            cell(item.platform, width: LedgerMetrics.platform, weight: .semibold)
            cell(item.username, width: LedgerMetrics.user)
            passwordCell
                .frame(width: LedgerMetrics.password, alignment: .leading)
            copyCell
                .frame(width: LedgerMetrics.action)
        }
        .frame(minHeight: 50, alignment: .top)
        .background(LockTheme.canvas)
        .overlay(alignment: .bottom) { Rectangle().fill(LockTheme.rule).frame(height: 1) }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy username") { clipboard.copy(item.username, label: "Username") }
            Button("Copy password") { clipboard.copy(item.password, label: "Password") }
            Divider()
            Button("Edit") { onEdit(item) }
            Button("Delete", role: .destructive) { confirmsDelete = true }
        }
        .alert("Delete \(item.platform)?", isPresented: $confirmsDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete(item) }
        } message: {
            Text("This credential will be removed from the encrypted vault.")
        }
    }

    private func cell(_ value: String, width: CGFloat, weight: Font.Weight = .regular) -> some View {
        Text(value)
            .font(.system(size: 12, weight: weight, design: .monospaced))
            .foregroundStyle(LockTheme.text)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .frame(width: width - 22, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 11)
    }

    private var passwordCell: some View {
        HStack(alignment: .top, spacing: 5) {
            Text(revealsPassword ? item.password : String(repeating: "•", count: min(item.password.count, 14)))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(revealsPassword ? LockTheme.text : LockTheme.muted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                revealsPassword.toggle()
            } label: {
                Image(systemName: revealsPassword ? "eye.slash" : "eye")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LockTheme.muted)
            }
            .buttonStyle(.plain)
            .help(revealsPassword ? "Hide password" : "Reveal password")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 11)
    }

    private var copyCell: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button("Password") { clipboard.copy(item.password, label: "Password") }
                .buttonStyle(LockButtonStyle())
            Button("User") { clipboard.copy(item.username, label: "Username") }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(LockTheme.accentForeground)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 9)
    }
}

import AppKit
import SwiftUI

struct VaultView: View {
    @EnvironmentObject private var store: VaultStore
    @EnvironmentObject private var clipboard: ClipboardController
    @State private var query = ""
    @State private var editorItem: VaultItem?
    @State private var showsEditor = false
    @State private var showsGenerator = false
    @State private var showsSecurity = false

    private var filteredItems: [VaultItem] {
        guard !query.isEmpty else { return store.document.items }
        return store.document.items.filter {
            $0.platform.localizedCaseInsensitiveContains(query)
                || $0.username.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            switch store.state {
            case .locked:
                lockedView
            case .unlocking:
                openingView
            case .locking:
                lockingView
            case .failed(let message):
                unavailableView(message: message)
            case .unlocked:
                if showsEditor {
                    credentialEditor
                } else {
                    vaultContent
                }
            }
        }
        .foregroundStyle(LockTheme.text)
        .frame(width: 720, height: 560)
        .background(LockTheme.surface)
        .onAppear { store.unlock() }
        .sheet(isPresented: $showsGenerator) { GeneratorView() }
        .sheet(isPresented: $showsSecurity) { SecurityFeaturesView() }
    }

    private var credentialEditor: some View {
        CredentialEditorView(
            item: editorItem,
            onCancel: closeEditor,
            onSave: { item in
                store.upsert(item)
                closeEditor()
            }
        )
    }

    private func closeEditor() {
        showsEditor = false
        editorItem = nil
    }

    private var vaultContent: some View {
        VStack(spacing: 12) {
            header
            toolbar
            CredentialTableView(
                items: filteredItems,
                onEdit: { item in
                    editorItem = item
                    showsEditor = true
                },
                onDelete: store.delete
            )
            .environmentObject(clipboard)

            HStack {
                Text("\(filteredItems.count) \(filteredItems.count == 1 ? "entry" : "entries")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LockTheme.muted)
                Spacer()
                if let copied = clipboard.copiedLabel {
                    Label("\(copied) copied · clears in 30s", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(LockTheme.accentForeground)
                        .transition(.opacity)
                }
                if let error = store.saveError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(LockTheme.warning)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 10, design: .rounded))
            .frame(height: 16)
        }
        .padding(20)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LockTheme.accent.opacity(0.13))
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LockTheme.accentForeground)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text("TERMILOCK")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .tracking(1.1)
                Text("PRIVATE CREDENTIAL LEDGER")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(LockTheme.muted)
            }
            Spacer()
            Button { showsSecurity = true } label: {
                Label("Security", systemImage: "person.badge.shield.checkmark")
            }
            .buttonStyle(LockButtonStyle())
            Button {
                Task {
                    await store.lock()
                    guard store.state == .locked else { return }
                    NSApp.keyWindow?.orderOut(nil)
                }
            } label: {
                Image(systemName: "lock.fill")
            }
            .buttonStyle(LockButtonStyle())
            .help("Relock vault")
            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "power")
            }
            .buttonStyle(LockButtonStyle())
            .help("Quit Termilock")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(LockTheme.muted)
                TextField("Find platform or user", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(LockTheme.canvas)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(LockTheme.rule, lineWidth: 1)
            }
            Button { showsGenerator = true } label: {
                Label("Generate", systemImage: "dice.fill")
            }
            .buttonStyle(LockButtonStyle())
            Button {
                editorItem = nil
                showsEditor = true
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(LockButtonStyle(prominent: true))
        }
    }

    private var openingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(LockTheme.accentForeground)
            Text("Opening vault…")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LockTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lockingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(LockTheme.accentForeground)
            Text("Securing vault…")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LockTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lockedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(LockTheme.accentForeground)
            Text("Vault locked")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text("Reopen Termilock from the menu bar to authenticate.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(LockTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func unavailableView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.lock.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(LockTheme.warning)
            Text("Vault unavailable")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(message)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(LockTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button("Try again") { store.unlock() }
                .buttonStyle(LockButtonStyle(prominent: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

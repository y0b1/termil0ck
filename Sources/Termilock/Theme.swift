import SwiftUI

enum LockTheme {
    static let canvas = Color.black
    static let surface = Color.black
    static let raised = Color(red: 6 / 255, green: 8 / 255, blue: 14 / 255)
    static let accent = Color(red: 10 / 255, green: 32 / 255, blue: 106 / 255)
    static let accentForeground = Color(red: 126 / 255, green: 153 / 255, blue: 255 / 255)
    static let rule = accent.opacity(0.78)
    static let text = Color(red: 240 / 255, green: 243 / 255, blue: 250 / 255)
    static let muted = Color(red: 139 / 255, green: 148 / 255, blue: 169 / 255)
    static let warning = Color(red: 218 / 255, green: 163 / 255, blue: 86 / 255)
}

struct LockButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(prominent ? Color.white : LockTheme.text)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(prominent ? LockTheme.accent : LockTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(LockTheme.rule, lineWidth: 1)
            }
            .opacity(!isEnabled ? 0.38 : configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func lockField() -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(LockTheme.canvas)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(LockTheme.rule, lineWidth: 1)
            }
    }
}

import AppKit
import SwiftUI

struct TopBarView: View {
    @Binding var selection: AppSection
    @State private var showsWindowControls = false

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 11) {
                if showsWindowControls {
                    WindowControlsView()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                AppIconImage(size: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Work Log")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.workLogIconGreenDark)
                    Text(selection.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.workLogHeaderText)
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.16)) {
                    showsWindowControls = hovering
                }
            }

            Spacer()

            HStack(spacing: 14) {
                ForEach(AppSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: section.systemImage)
                                .foregroundStyle(selection == section ? .workLogSkyBlue : .secondary)
                            Text(section.rawValue)
                                .foregroundStyle(selection == section ? .primary : .secondary)
                        }
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selection == section ? Color.workLogSkyBlue.opacity(0.18) : Color.primary.opacity(0.001))
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.thinMaterial)
    }
}

private struct WindowControlsView: View {
    var body: some View {
        HStack(spacing: 8) {
            WindowControlButton(color: .red, accessibilityLabel: "Close") {
                (NSApp.keyWindow ?? NSApp.mainWindow)?.performClose(nil)
            }

            WindowControlButton(color: .yellow, accessibilityLabel: "Minimize") {
                (NSApp.keyWindow ?? NSApp.mainWindow)?.miniaturize(nil)
            }

            WindowControlButton(color: .green, accessibilityLabel: "Full Screen") {
                (NSApp.keyWindow ?? NSApp.mainWindow)?.toggleFullScreen(nil)
            }
        }
        .frame(width: 56, alignment: .leading)
        .padding(.trailing, 2)
    }
}

private struct WindowControlButton: View {
    var color: Color
    var accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.opacity(0.9))
                .frame(width: 12, height: 12)
                .overlay {
                    Circle()
                        .stroke(.black.opacity(0.12), lineWidth: 0.5)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct AppIconImage: View {
    var size: CGFloat

    var body: some View {
        Group {
            WorkLogIconMark()
        }
        .frame(width: size, height: size)
        .shadow(color: Color.workLogSkyBlue.opacity(0.18), radius: 4, y: 1)
    }
}

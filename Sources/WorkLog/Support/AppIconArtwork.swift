import AppKit
import SwiftUI

struct WorkLogIconMark: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.55, blue: 0.55),
                                Color(red: 0.08, green: 0.14, blue: 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: max(size * 0.025, 1))

                RoundedRectangle(cornerRadius: size * 0.11, style: .continuous)
                    .fill(Color(red: 0.95, green: 0.97, blue: 0.95))
                    .frame(width: size * 0.56, height: size * 0.58)
                    .offset(x: -size * 0.04, y: size * 0.02)
                    .shadow(color: .black.opacity(0.20), radius: size * 0.05, y: size * 0.025)

                VStack(spacing: size * 0.055) {
                    ForEach(0..<4, id: \.self) { index in
                        HStack(spacing: size * 0.035) {
                            RoundedRectangle(cornerRadius: size * 0.018)
                                .fill(index == 0 ? Color(red: 0.10, green: 0.56, blue: 0.66) : Color(red: 0.72, green: 0.78, blue: 0.76))
                                .frame(width: size * 0.14, height: size * 0.035)
                            RoundedRectangle(cornerRadius: size * 0.018)
                                .fill(Color(red: 0.79, green: 0.84, blue: 0.82))
                                .frame(width: size * 0.24, height: size * 0.035)
                        }
                    }
                }
                .offset(x: -size * 0.04, y: size * 0.02)

                Circle()
                    .fill(Color(red: 0.05, green: 0.56, blue: 0.48))
                    .frame(width: size * 0.30, height: size * 0.30)
                    .offset(x: size * 0.20, y: size * 0.20)
                    .shadow(color: .black.opacity(0.20), radius: size * 0.035, y: size * 0.02)

                CheckmarkShape()
                    .stroke(.white, style: StrokeStyle(lineWidth: max(size * 0.045, 2), lineCap: .round, lineJoin: .round))
                    .frame(width: size * 0.17, height: size * 0.12)
                    .offset(x: size * 0.20, y: size * 0.20)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

enum AppIconRenderer {
    @MainActor
    static func makeImage(size: CGFloat) -> NSImage {
        let view = WorkLogIconMark()
            .frame(width: size, height: size)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: size, height: size)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return NSImage(size: NSSize(width: size, height: size))
        }

        bitmap.size = NSSize(width: size, height: size)
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(bitmap)
        return image
    }
}

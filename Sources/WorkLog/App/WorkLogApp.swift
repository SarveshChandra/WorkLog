import AppKit
import SwiftUI

@main
struct WorkLogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup("Work Log") {
            ContentView()
                .font(.custom("Helvetica Neue", size: 14))
                .environmentObject(store)
                .frame(minWidth: 1180, minHeight: 720)
        }
        .defaultSize(width: 1320, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Work Log") {
                    store.addWorkExperience()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("New Interview Opportunity") {
                    store.addInterviewOpportunity()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Import Tasks...") {
                    store.importWorkExperiences()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])

                Button("Import Document...") {
                    store.importDocument()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }

            CommandGroup(after: .saveItem) {
                Button("Backup Now") {
                    store.backupNow()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .font(.custom("Helvetica Neue", size: 14))
                .environmentObject(store)
                .frame(width: 640, height: 520)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        hideApplicationMenuBar()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.positionMainWindowIfNeeded()
        }
    }

    @MainActor
    private func positionMainWindowIfNeeded() {
        guard let window = NSApp.windows.first(where: { $0.title == "Work Log" }),
              let screen = window.screen ?? NSScreen.main else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let isClipped = window.frame.minX < visibleFrame.minX
            || window.frame.maxX > visibleFrame.maxX
            || window.frame.minY < visibleFrame.minY
            || window.frame.maxY > visibleFrame.maxY

        if isClipped || window.frame.width < 1100 || window.frame.height < 680 {
            let width = min(CGFloat(1320), visibleFrame.width - 40)
            let height = min(CGFloat(760), visibleFrame.height - 40)
            window.setFrame(NSRect(x: 0, y: 0, width: width, height: height), display: true)
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        configureWindowChrome(window)
        hideApplicationMenuBar()
    }

    private func configureWindowChrome(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // Keep the window titled/resizable so it remains key/main and supports standard behaviors
        // like zoom and fullscreen. We hide the title bar via SwiftUI's `.hiddenTitleBar` style.
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true

        for buttonType in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(buttonType) else {
                continue
            }
            button.isHidden = true
        }
    }

    @MainActor
    private func hideApplicationMenuBar() {
        let emptyMenu = NSMenu(title: "")
        NSApp.mainMenu = emptyMenu
    }
}

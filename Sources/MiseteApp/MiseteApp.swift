import AppKit
import SwiftUI
import MiseteReceiver

@main
struct MiseteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var receiver = ReceiverController()

    var body: some Scene {
        Window("Misete — 見せて", id: "main") {
            ContentView(receiver: receiver)
                .onAppear {
                    delegate.receiver = receiver
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    if CommandLine.arguments.contains("--demo") {
                        receiver.startDemo()
                    } else if CommandLine.arguments.contains("--receive") {
                        receiver.start()
                    }
                }
        }
        .defaultSize(width: 1120, height: 740)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("受信") {
                Button("AirPlayを開始") { receiver.start() }
                    .keyboardShortcut("r", modifiers: [.command])
                Button("受信を停止") { receiver.stop() }
                    .keyboardShortcut(".", modifiers: [.command])
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var receiver: ReceiverController?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        receiver?.stop()
    }
}

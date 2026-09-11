import AppKit
import SwiftUI
import MiseteCore
import MiseteReceiver

struct ContentView: View {
    @ObservedObject var receiver: ReceiverController
    @State private var name = "Misete"
    @State private var muted = false
    @State private var requiresPairing = false
    @State private var showDiagnostics = false

    private var running: Bool {
        switch receiver.state {
        case .starting, .waiting, .streaming: return true
        case .idle, .failed: return false
        }
    }

    private var status: String {
        switch receiver.state {
        case .idle: return "停止中"
        case .starting: return "起動中…"
        case .waiting: return receiver.isDemo ? "テスト映像を準備中…" : "接続待ち"
        case .streaming: return receiver.isDemo ? "テスト映像" : "接続中"
        case .failed: return "エラー"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                TextField("AirPlay名", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .disabled(running)
                    .accessibilityLabel("AirPlay名")
                    .accessibilityIdentifier("receiverName")
                Toggle("音声", isOn: Binding(get: { !muted }, set: { muted = !$0 }))
                    .disabled(running)
                Toggle("接続コード", isOn: $requiresPairing)
                    .disabled(running)
                    .accessibilityIdentifier("requirePairing")
                Spacer()
                Button(running ? "停止" : "開始") {
                    if running {
                        receiver.stop()
                    } else {
                        receiver.start(name: name, muted: muted, requiresPairing: requiresPairing)
                    }
                }
                .accessibilityIdentifier("toggleReceiver")
            }
            .padding(12)

            Divider()
            ZStack {
                Color(nsColor: .textBackgroundColor)
                if let frame = receiver.frame {
                    Color.black
                    Image(nsImage: frame)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel(receiver.isDemo ? "テスト映像" : "共有画面")
                } else if case let .failed(message) = receiver.state {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .padding(24)
                }
                if let pin = receiver.pairingPIN, running, !receiver.isDemo {
                    VStack(spacing: 8) {
                        Text("接続コード").font(.headline)
                        Text(pin).font(.system(size: 40, weight: .medium, design: .monospaced))
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            Divider()

            HStack(spacing: 12) {
                Text(status).foregroundStyle(.secondary)
                Spacer()
                Button("表示テスト") { receiver.startDemo() }
                    .disabled(running)
                    .accessibilityIdentifier("startDemo")
                Button("診断") { showDiagnostics = true }
                Button("全画面") { NSApp.keyWindow?.toggleFullScreen(nil) }
            }
            .controlSize(.small)
            .padding(10)
        }
        .frame(minWidth: 620, minHeight: 420)
        .sheet(isPresented: $showDiagnostics) {
            VStack(alignment: .leading, spacing: 16) {
                Text("診断").font(.headline)
                ScrollView {
                    Text(receiver.diagnostics.isEmpty ? "メッセージはありません。" : receiver.diagnostics.joined(separator: "\n"))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 180)
                HStack {
                    Text("TCP / UDP 35000–35002").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("閉じる") { showDiagnostics = false }.keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 480)
        }
    }
}

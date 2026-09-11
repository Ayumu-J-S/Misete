import AppKit
import SwiftUI
import MiseteCore
import MiseteReceiver

struct ContentView: View {
    @ObservedObject var receiver: ReceiverController
    @State private var muted = false
    @State private var requiresPairing = false

    private var running: Bool {
        switch receiver.state {
        case .starting, .waiting, .streaming: return true
        case .idle, .failed: return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
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
            .background(VideoWindowFitter(videoSize: receiver.frame?.size))
        }
        .frame(minWidth: 260, minHeight: 240)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            settings
            Spacer(minLength: 0)
            Button(running ? "停止" : "開始") {
                if running {
                    receiver.stop()
                } else {
                    receiver.start(muted: muted, requiresPairing: requiresPairing)
                }
            }
            .accessibilityIdentifier("toggleReceiver")
        }
    }

    private var settings: some View {
        Group {
            Toggle("音声", isOn: Binding(get: { !muted }, set: { muted = !$0 }))
                .disabled(running)
            Toggle("接続コード", isOn: $requiresPairing)
                .disabled(running)
                .accessibilityIdentifier("requirePairing")
        }
    }

}

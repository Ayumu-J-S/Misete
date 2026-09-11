import AppKit
import SwiftUI
import MiseteCore
import MiseteReceiver

struct ContentView: View {
    @ObservedObject var receiver: ReceiverController
    @State private var name = "Misete"
    @State private var muted = false
    private var demo: Bool { receiver.isDemo }
    @State private var showDiagnostics = false

    private let mint = Color(red: 0.65, green: 0.93, blue: 0.79)
    private let ink = Color(red: 0.12, green: 0.17, blue: 0.16)

    private var running: Bool {
        switch receiver.state {
        case .starting, .waiting, .streaming: return true
        case .idle, .failed: return false
        }
    }

    private var status: String {
        switch receiver.state {
        case .idle: return "受信を開始できます"
        case .starting: return "受信を準備しています"
        case .waiting: return demo ? "テスト映像を準備中" : "iPadからの接続を待っています"
        case .streaming: return demo ? "テスト映像を表示中" : "画面を共有しています"
        case .failed: return "接続を確認してください"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 286)
            VStack(spacing: 0) {
                header
                stage
                    .padding(.horizontal, 28)
                footer
            }
            .background(Color(red: 0.95, green: 0.96, blue: 0.94))
        }
        .foregroundStyle(ink)
        .frame(minWidth: 940, minHeight: 660)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showDiagnostics) { diagnostics }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(mint, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Misete").font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("見せて。").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 22)

            VStack(alignment: .leading, spacing: 9) {
                Text("その画面を、\nここに。").font(.system(size: 30, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("iPadからMacへ。\n同じWi-Fiで、すぐに共有。")
                    .font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("AIRPLAYの表示名").font(.system(size: 10, weight: .semibold)).tracking(1.2)
                TextField("Misete", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .disabled(running)
                    .accessibilityIdentifier("receiverName")
                Toggle("iPadの音声を再生", isOn: Binding(
                    get: { !muted }, set: { muted = !$0 }
                ))
                .font(.system(size: 12))
                .disabled(running)
                Text("音声と表示名の変更は停止中にできます。")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }

            Button(action: toggleReceiver) {
                HStack {
                    Image(systemName: running ? "stop.fill" : "airplayvideo")
                    Text(running ? "受信を停止" : "AirPlayを開始")
                        .fontWeight(.semibold)
                    Spacer()
                    if !running { Image(systemName: "arrow.up.right") }
                }
                .padding(14)
                .foregroundStyle(running ? ink : .white)
                .background(running ? Color.black.opacity(0.06) : ink,
                            in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("toggleReceiver")

            if let pin = receiver.pairingPIN, running, !demo {
                VStack(alignment: .leading, spacing: 6) {
                    Text("接続コード").font(.system(size: 11, weight: .medium))
                    Text(pin).font(.system(size: 32, weight: .medium, design: .monospaced)).tracking(7)
                    Text("iPadで求められたら入力してください。")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(mint.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 12) {
                Label("このMacで受信・表示", systemImage: "lock.shield")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Button("接続の診断") { showDiagnostics = true }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(.white)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("スクリーン共有").font(.system(size: 20, weight: .semibold))
                HStack(spacing: 6) {
                    Circle().fill(running ? Color.green : Color.gray).frame(width: 6, height: 6)
                    Text(status).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(demo ? "表示テスト" : "AIRPLAY")
                .font(.system(size: 10, weight: .semibold)).tracking(1)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.white, in: Capsule())
        }
        .padding(.horizontal, 28).padding(.top, 34).padding(.bottom, 24)
    }

    private var stage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(ink)
            if let frame = receiver.frame {
                Image(nsImage: frame)
                    .resizable().interpolation(.high).scaledToFit()
                    .padding(12)
                    .accessibilityLabel(demo ? "テスト映像" : "iPadの共有画面")
            } else {
                VStack(spacing: 24) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "ipad.landscape")
                            .font(.system(size: 82, weight: .ultraLight))
                            .foregroundStyle(mint)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 23, weight: .medium))
                            .padding(12).background(ink, in: Circle()).offset(x: 10, y: 10)
                    }
                    VStack(spacing: 10) {
                        Text(demo && running ? "テスト映像を準備しています" :
                                running ? "iPadで「\(receiver.receiverName)」を選択" : "見せたいものを、大きく。")
                            .font(.system(size: 23, weight: .medium))
                        Text(demo && running ? "このMacで映像の表示を確認します。" :
                                running ? "コントロールセンター → 画面ミラーリング" : "「AirPlayを開始」して、iPadをつなぎましょう。")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                    }
                    if case let .failed(message) = receiver.state {
                        Text(message)
                            .font(.system(size: 12)).foregroundStyle(Color.orange.opacity(0.95))
                            .multilineTextAlignment(.center).textSelection(.enabled)
                            .frame(maxWidth: 470)
                    }
                }
                .foregroundStyle(.white).padding(30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay(alignment: .topLeading) {
            if receiver.frame != nil {
                Label(demo ? "DEMO" : "LIVE", systemImage: "circle.fill")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(mint)
                    .padding(9).background(ink.opacity(0.8), in: Capsule()).padding(16)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 18) {
                instruction("1", "同じWi-Fi", "MacとiPadを接続")
                instruction("2", "画面ミラーリング", "iPadの右上から下にスワイプ")
                instruction("3", "接続先を選ぶ", "接続コードを入力して共有")
            }
            HStack {
                Button("iPadなしで表示テスト") {
                    receiver.startDemo()
                }
                .disabled(running).buttonStyle(.plain)
                .accessibilityIdentifier("startDemo")
                Spacer()
                if receiver.frameCount > 0 {
                    Text("\(receiver.frameCount) frames").monospacedDigit()
                }
                Button {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                } label: {
                    Label("全画面", systemImage: "arrow.up.left.and.arrow.down.right")
                }.buttonStyle(.plain)
            }
            .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(28)
    }

    private func instruction(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number).font(.system(size: 10, weight: .semibold))
                .frame(width: 21, height: 21).background(.white, in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 11, weight: .semibold))
                Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("接続の診断").font(.title2.bold())
            Text("MacとiPadを同じWi-Fiに接続してください。macOSでローカルネットワークへのアクセスを求められた場合は、許可が必要です。VPNやWi-Fiの端末間通信制限も確認してください。")
                .font(.callout).foregroundStyle(.secondary)
            ScrollView {
                Text(receiver.diagnostics.isEmpty ? "診断メッセージはありません。" : receiver.diagnostics.joined(separator: "\n"))
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
            .frame(height: 200).padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Text("AirPlay: TCP / UDP 35000–35002").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("閉じる") { showDiagnostics = false }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(28).frame(width: 540)
    }

    private func toggleReceiver() {
        if running {
            receiver.stop()
        } else {
            receiver.start(name: name, muted: muted)
        }
    }
}

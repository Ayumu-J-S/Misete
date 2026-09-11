import AppKit
import Combine
import Darwin
import Foundation
import MiseteCore

@MainActor
public final class ReceiverController: ObservableObject {
    @Published public private(set) var state: ReceiverState = .idle
    @Published public private(set) var frame: NSImage?
    @Published public private(set) var frameCount = 0
    @Published public private(set) var pairingPIN: String?
    @Published public private(set) var diagnostics: [String] = []
    @Published public private(set) var receiverName = "Misete"
    @Published public private(set) var isDemo = false

    private let uxplayURL: URL?
    private var process: Process?
    private var frameServer: LoopbackFrameServer?
    private var runID = UUID()

    public init(uxplayURL: URL? = nil) {
        self.uxplayURL = uxplayURL
    }

    public func start(name: String = "Misete", muted: Bool = false) {
        stop()
        state = .starting
        receiverName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        frame = nil
        frameCount = 0
        diagnostics = ["Preparing the local frame receiver."]
        isDemo = false
        let currentRun = runID
        pairingPIN = nil

        Task { [weak self] in
            await self?.startReceiver(name: name, muted: muted, runID: currentRun)
        }
    }

    public func startDemo() {
        stop()
        state = .starting
        receiverName = "Misete"
        frame = nil
        frameCount = 0
        pairingPIN = nil
        diagnostics = ["Preparing the local display test."]
        isDemo = true
        let currentRun = runID
        Task { [weak self] in
            await self?.startDemoProcess(runID: currentRun)
        }
    }

    public func stop() {
        runID = UUID()
        frameServer?.stop()
        frameServer = nil
        terminateCurrentProcess()
        pairingPIN = nil
        frame = nil
        frameCount = 0
        isDemo = false
        state = .idle
    }

    private func startReceiver(name: String, muted: Bool, runID: UUID) async {
        do {
            let registrationFile = try Self.registrationFile()
            let server = makeFrameServer(runID: runID)
            let port = try await server.start()
            guard self.runID == runID else { server.stop(); return }
            frameServer = server
            let configuration = try ReceiverConfiguration(
                receiverName: name,
                framePort: Int(port),
                registrationFile: registrationFile,
                muted: muted
            )
            receiverName = configuration.receiverName
            let executable = try ExecutableResolver.uxPlay(explicit: uxplayURL)
            try launch(executable: executable, arguments: configuration.uxPlayArguments, runID: runID, readinessRequired: true)
        } catch {
            fail(error.localizedDescription, runID: runID)
        }
    }

    private func startDemoProcess(runID: UUID) async {
        do {
            let server = makeFrameServer(runID: runID)
            let port = try await server.start()
            guard self.runID == runID else { server.stop(); return }
            frameServer = server
            let executable = try ExecutableResolver.gstLaunch()
            let arguments = [
                "-q", "videotestsrc", "is-live=true", "pattern=smpte", "!",
                "video/x-raw,framerate=30/1", "!", "videoconvert", "!",
                "jpegenc", "quality=85", "!", "tcpclientsink",
                "host=127.0.0.1", "port=\(port)", "sync=false"
            ]
            try launch(executable: executable, arguments: arguments, runID: runID, readinessRequired: false)
        } catch {
            fail(error.localizedDescription, runID: runID)
        }
    }

    private func makeFrameServer(runID: UUID) -> LoopbackFrameServer {
        let delivery = LatestFrameDelivery { [weak self] data in
            guard let self, self.runID == runID, let image = NSImage(data: data) else { return }
            self.frame = image
            self.frameCount += 1
            self.pairingPIN = nil
            self.state = .streaming
        }
        return LoopbackFrameServer(onConnectionChange: { [weak self] connected in
            guard !connected else { return }
            Task { @MainActor [weak self] in
                guard let self, self.runID == runID, self.process?.isRunning == true else { return }
                self.frame = nil
                self.pairingPIN = nil
                self.state = .waiting
                self.addDiagnostic("Sender disconnected; waiting for reconnection.")
            }
        }) { data in
            delivery.submit(data)
        }
    }

    private func launch(executable: URL, arguments: [String], runID: UUID, readinessRequired: Bool) throws {
        let child = Process()
        child.executableURL = executable
        child.arguments = arguments
        child.environment = ExecutableResolver.processEnvironment()
        let output = Pipe()
        child.standardOutput = output
        child.standardError = output

        let outputQueue = DispatchQueue(label: "app.misete.process-output")
        var outputBuffer = ProcessOutputBuffer()
        output.fileHandleForReading.readabilityHandler = { [weak self, weak child] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            outputQueue.async {
                for line in outputBuffer.append(data) {
                    guard let event = ProcessEventParser.event(for: line) else { continue }
                    Task { @MainActor [weak self, weak child] in
                        guard let self, let child, self.runID == runID, self.process === child else { return }
                        switch event {
                        case .advertised:
                            self.addDiagnostic("AirPlay service advertised on the local network.")
                            if self.state == .starting { self.state = .waiting }
                        case .pairingPIN(let pin):
                            self.pairingPIN = pin
                        case .clientRegistered:
                            self.pairingPIN = nil
                        }
                    }
                }
            }
        }
        child.terminationHandler = { [weak self, weak child] terminated in
            output.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor [weak self, weak child] in
                guard let self, let child, self.runID == runID, self.process === child else { return }
                self.process = nil
                self.frameServer?.stop()
                self.frameServer = nil
                self.frame = nil
                self.pairingPIN = nil
                self.isDemo = false
                let code = terminated.terminationStatus
                self.state = .failed(code == 0
                    ? "The receiver stopped unexpectedly. Start it again."
                    : "The receiver could not continue (exit \(code)). Check that ports 35000–35002 are available and try again.")
                self.addDiagnostic("Receiver process exited with status \(code).")
            }
        }
        try child.run()
        guard self.runID == runID else { child.terminate(); return }
        process = child
        addDiagnostic(readinessRequired ? "UxPlay started; confirming AirPlay advertisement." : "Display test process started.")
        if !readinessRequired { state = .waiting }
        if readinessRequired {
            Task { [weak self, weak child] in
                try? await Task.sleep(for: .seconds(8))
                guard let self, let child, self.runID == runID, self.process === child, self.state == .starting else { return }
                self.fail("AirPlay advertisement did not become ready. Check local network access and ports 35000–35002.", runID: runID)
            }
        }
    }

    private func terminateCurrentProcess() {
        guard let oldProcess = process else { return }
        process = nil
        oldProcess.terminationHandler = nil
        (oldProcess.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        guard oldProcess.isRunning else { return }
        let pid = oldProcess.processIdentifier
        oldProcess.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            guard oldProcess.isRunning, oldProcess.processIdentifier == pid else { return }
            Darwin.kill(pid, SIGKILL)
        }
    }

    private func fail(_ message: String, runID: UUID) {
        guard self.runID == runID else { return }
        frameServer?.stop()
        frameServer = nil
        terminateCurrentProcess()
        pairingPIN = nil
        frame = nil
        state = .failed(message)
        addDiagnostic(message)
    }

    private func addDiagnostic(_ message: String) {
        diagnostics = Array((diagnostics + [message]).suffix(50))
    }

    private static func registrationFile() throws -> URL {
        let manager = FileManager.default
        let support = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("Misete", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let directoryValues = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard directoryValues.isDirectory == true, directoryValues.isSymbolicLink != true else {
            throw CocoaError(.fileWriteNoPermission)
        }
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let file = directory.appendingPathComponent("paired-clients.register")
        if !manager.fileExists(atPath: file.path) {
            guard manager.createFile(atPath: file.path, contents: Data(), attributes: [.posixPermissions: 0o600]) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        let fileValues = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard fileValues.isRegularFile == true, fileValues.isSymbolicLink != true else {
            throw CocoaError(.fileWriteNoPermission)
        }
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return file
    }
}

enum ProcessEvent: Equatable {
    case advertised
    case pairingPIN(String)
    case clientRegistered
}

enum ProcessEventParser {
    static func event(for line: String) -> ProcessEvent? {
        if line.contains("register_dnssd: advertised AirPlay service") { return .advertised }
        if line.contains("registered new client:") { return .clientRegistered }
        let marker = "CLIENT MUST NOW ENTER PIN = \""
        guard let markerRange = line.range(of: marker) else { return nil }
        let remainder = line[markerRange.upperBound...]
        guard remainder.count >= 5 else { return nil }
        let pin = String(remainder.prefix(4))
        guard pin.utf8.allSatisfy({ (48...57).contains($0) }),
              remainder.dropFirst(4).first == "\"" else { return nil }
        return .pairingPIN(pin)
    }
}

private final class LatestFrameDelivery: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: Data?
    private var scheduled = false
    private let handler: @MainActor (Data) -> Void

    init(handler: @escaping @MainActor (Data) -> Void) {
        self.handler = handler
    }

    func submit(_ data: Data) {
        let shouldSchedule = lock.withLock { () -> Bool in
            pending = data
            guard !scheduled else { return false }
            scheduled = true
            return true
        }
        guard shouldSchedule else { return }
        Task { @MainActor [self] in
            guard let latest = lock.withLock({ () -> Data? in
                defer { pending = nil; scheduled = false }
                return pending
            }) else { return }
            handler(latest)
        }
    }
}

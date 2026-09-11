import Foundation
import MiseteCore
import XCTest
@testable import MiseteReceiver

final class ReceiverControllerTests: XCTestCase {
    func testWaitsForAdvertisementAndDoesNotRetainSensitiveOutput() async throws {
        let script = try makeScript("""
        echo 'connection request deviceID = AA:BB:CC client Secret iPad'
        echo '*** CLIENT MUST NOW ENTER PIN = "0427" AS AIRPLAY PASSWORD'
        sleep 0.1
        echo 'register_dnssd: advertised AirPlay service'
        while :; do sleep 1; done
        """)
        defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }
        let controller = await MainActor.run { ReceiverController(uxplayURL: script) }

        await MainActor.run { controller.start(requiresPairing: true) }
        try await waitUntil { await MainActor.run { controller.state == .waiting } }
        let snapshot = await MainActor.run { (controller.pairingPIN, controller.diagnostics) }
        XCTAssertEqual(snapshot.0, "0427")
        XCTAssertFalse(snapshot.1.joined().contains("AA:BB"))
        XCTAssertFalse(snapshot.1.joined().contains("Secret iPad"))
        if let pin = snapshot.0 { XCTAssertFalse(snapshot.1.joined().contains(pin)) }
        await MainActor.run { controller.stop() }
    }

    func testUnexpectedProcessExitBecomesFailureAndClearsPIN() async throws {
        let script = try makeScript("exit 7")
        defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }
        let controller = await MainActor.run { ReceiverController(uxplayURL: script) }

        await MainActor.run { controller.start() }
        try await waitUntil {
            await MainActor.run {
                if case .failed = controller.state { return true }
                return false
            }
        }
        let snapshot = await MainActor.run { (controller.state, controller.pairingPIN, controller.frame) }
        XCTAssertEqual(snapshot.0, .failed("The receiver could not continue (exit 7). Check that ports 35000–35002 are available and try again."))
        XCTAssertNil(snapshot.1)
        XCTAssertNil(snapshot.2)
    }

    func testDemoUsesGStreamerAndProducesAnImage() async throws {
        guard (try? ExecutableResolver.gstLaunch()) != nil else {
            throw XCTSkip("GStreamer is not installed")
        }
        let controller = await MainActor.run { ReceiverController() }
        await MainActor.run { controller.startDemo() }
        try await waitUntil(timeout: .seconds(5)) {
            await MainActor.run { controller.state == .streaming && controller.frame != nil }
        }
        let count = await MainActor.run { controller.frameCount }
        XCTAssertGreaterThan(count, 0)
        await MainActor.run { controller.stop() }
    }

    func testRestartIgnoresOldProcessTerminationCallbacks() async throws {
        let script = try makeScript("""
        echo 'register_dnssd: advertised AirPlay service'
        while :; do sleep 1; done
        """)
        defer { try? FileManager.default.removeItem(at: script.deletingLastPathComponent()) }
        let controller = await MainActor.run { ReceiverController(uxplayURL: script) }
        await MainActor.run { controller.start() }
        try await waitUntil { await MainActor.run { controller.state == .waiting } }

        await MainActor.run { controller.start(name: "Misete Again") }
        try await waitUntil { await MainActor.run { controller.state == .waiting } }
        try await Task.sleep(for: .milliseconds(100))
        let snapshot = await MainActor.run { (controller.state, controller.receiverName) }
        XCTAssertEqual(snapshot.0, .waiting)
        XCTAssertEqual(snapshot.1, "Misete Again")
        await MainActor.run { controller.stop() }
    }

    private func makeScript(_ body: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let script = directory.appendingPathComponent("fake-uxplay")
        try Data("#!/bin/sh\n\(body)\n".utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return script
    }

    private func waitUntil(
        timeout: Duration = .seconds(3),
        predicate: @escaping () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Condition did not become true before timeout")
    }
}

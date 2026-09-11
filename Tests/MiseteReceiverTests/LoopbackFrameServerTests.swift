import Foundation
import Network
import XCTest
@testable import MiseteReceiver

final class LoopbackFrameServerTests: XCTestCase {
    func testReceivesFragmentedFramesAndAcceptsReconnect() async throws {
        let frame = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
        let received = expectation(description: "two frames")
        received.expectedFulfillmentCount = 2
        let values = LockedValues()
        let server = LoopbackFrameServer { value in
            values.append(value)
            received.fulfill()
        }
        let port = try await server.start()

        try await send([frame.prefix(3), frame.suffix(from: 3)], to: port)
        try await send([frame[...]], to: port)
        await fulfillment(of: [received], timeout: 3)
        server.stop()

        XCTAssertEqual(values.snapshot, [frame, frame])
    }

    func testCapsConnectionsAndReleasesCapacityAfterDisconnect() async throws {
        let server = LoopbackFrameServer(maximumConcurrentConnections: 4) { _ in }
        let port = try await server.start()
        defer { server.stop() }

        var clients: [NWConnection] = []
        for _ in 0..<4 {
            clients.append(try await connect(to: port))
        }
        try await waitUntil { server.activeConnectionCount == 4 }

        let rejected = try await connect(to: port)
        clients.append(rejected)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(server.activeConnectionCount, 4)

        clients[0].cancel()
        try await waitUntil { server.activeConnectionCount == 3 }
        clients.append(try await connect(to: port))
        try await waitUntil { server.activeConnectionCount == 4 }

        clients.forEach { $0.cancel() }
    }

    private func send(_ chunks: [Data.SubSequence], to port: UInt16) async throws {
        let connection = try await connect(to: port)
        for (index, chunk) in chunks.enumerated() {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let final = index == chunks.count - 1
                connection.send(content: Data(chunk), contentContext: .defaultMessage, isComplete: final, completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                })
            }
        }
        connection.cancel()
    }

    private func connect(to port: UInt16) async throws -> NWConnection {
        let connection = NWConnection(
            host: .ipv4(.loopback),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        let ready = expectation(description: "connected")
        connection.stateUpdateHandler = { state in
            if case .ready = state { ready.fulfill() }
        }
        connection.start(queue: .global())
        await fulfillment(of: [ready], timeout: 2)
        return connection
    }

    private func waitUntil(timeout: Duration = .seconds(2), predicate: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition did not become true before timeout")
    }
}

private final class LockedValues: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Data] = []

    func append(_ value: Data) { lock.withLock { values.append(value) } }
    var snapshot: [Data] { lock.withLock { values } }
}

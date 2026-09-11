import Foundation
import MiseteCore
import Network

public final class LoopbackFrameServer: @unchecked Sendable {
    public typealias FrameHandler = @Sendable (Data) -> Void

    private let queue = DispatchQueue(label: "app.misete.frame-server", qos: .userInteractive)
    private let frameHandler: FrameHandler
    private let connectionHandler: @Sendable (Bool) -> Void
    private let maximumFrameBytes: Int
    private let maximumConcurrentConnections: Int
    private let lock = NSLock()
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var readyConnections: Set<ObjectIdentifier> = []

    public init(
        maximumFrameBytes: Int = 8 * 1_024 * 1_024,
        maximumConcurrentConnections: Int = 4,
        onConnectionChange: @escaping @Sendable (Bool) -> Void = { _ in },
        onFrame: @escaping FrameHandler
    ) {
        precondition(maximumConcurrentConnections > 0)
        self.maximumFrameBytes = maximumFrameBytes
        self.maximumConcurrentConnections = maximumConcurrentConnections
        self.connectionHandler = onConnectionChange
        self.frameHandler = onFrame
    }

    public func start() async throws -> UInt16 {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let newListener = try NWListener(using: parameters)
        let alreadyStarted = lock.withLock { () -> Bool in
            guard listener == nil else { return true }
            listener = newListener
            return false
        }
        guard !alreadyStarted else {
            throw NWError.posix(.EALREADY)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let completion = StartCompletion(continuation)
            newListener.stateUpdateHandler = { [weak self, weak newListener] state in
                switch state {
                case .ready:
                    guard let port = newListener?.port?.rawValue else {
                        completion.resume(.failure(NWError.posix(.EINVAL)))
                        return
                    }
                    completion.resume(.success(port))
                case .failed(let error):
                    self?.stop()
                    completion.resume(.failure(error))
                case .cancelled:
                    completion.resume(.failure(NWError.posix(.ECANCELED)))
                default:
                    break
                }
            }
            newListener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            newListener.start(queue: queue)
        }
    }

    public func stop() {
        let (oldListener, oldConnections) = lock.withLock { () -> (NWListener?, [NWConnection]) in
            let values = (listener, Array(connections.values))
            listener = nil
            connections.removeAll()
            readyConnections.removeAll()
            return values
        }
        oldListener?.cancel()
        oldConnections.forEach { $0.cancel() }
    }

    private func accept(_ connection: NWConnection) {
        let identifier = ObjectIdentifier(connection)
        let accepted = lock.withLock { () -> Bool in
            guard listener != nil, connections.count < maximumConcurrentConnections else { return false }
            connections[identifier] = connection
            return true
        }
        guard accepted else {
            connection.cancel()
            return
        }
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            switch state {
            case .ready:
                guard let self, let connection else { return }
                self.lock.withLock { _ = self.readyConnections.insert(identifier) }
                self.connectionHandler(true)
                self.receive(from: connection, parser: JPEGFrameParser(maximumFrameBytes: self.maximumFrameBytes))
            case .failed, .cancelled:
                self?.removeConnection(identifier)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func receive(from connection: NWConnection, parser: JPEGFrameParser) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1_024) { [weak self] data, _, complete, error in
            guard let self else { return }
            var nextParser = parser
            if let data, !data.isEmpty {
                do {
                    let frames = try nextParser.append(data)
                    // Keeping the newest frame bounds work when several arrive in one network read.
                    if let latest = frames.last { self.frameHandler(latest) }
                } catch {
                    nextParser.reset()
                }
            }
            if complete || error != nil {
                connection.cancel()
                self.removeConnection(ObjectIdentifier(connection))
            } else {
                self.receive(from: connection, parser: nextParser)
            }
        }
    }

    private func removeConnection(_ identifier: ObjectIdentifier) {
        let becameDisconnected = lock.withLock { () -> Bool in
            _ = connections.removeValue(forKey: identifier)
            let wasReady = readyConnections.remove(identifier) != nil
            return wasReady && readyConnections.isEmpty
        }
        if becameDisconnected { connectionHandler(false) }
    }

    var activeConnectionCount: Int {
        lock.withLock { connections.count }
    }
}

private final class StartCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<UInt16, Error>?

    init(_ continuation: CheckedContinuation<UInt16, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<UInt16, Error>) {
        let pending = lock.withLock { () -> CheckedContinuation<UInt16, Error>? in
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(with: result)
    }
}

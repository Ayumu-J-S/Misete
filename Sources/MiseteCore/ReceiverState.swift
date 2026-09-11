public enum ReceiverState: Equatable, Sendable {
    case idle
    case starting
    case waiting
    case streaming
    case failed(String)
}

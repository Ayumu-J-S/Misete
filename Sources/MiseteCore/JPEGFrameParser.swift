import Foundation

public enum JPEGFrameParserError: Error, Equatable {
    case frameTooLarge(limit: Int)
}

public struct JPEGFrameParser: Sendable {
    public let maximumFrameBytes: Int
    private var buffer = Data()

    public init(maximumFrameBytes: Int = 8 * 1_024 * 1_024) {
        precondition(maximumFrameBytes >= 4)
        self.maximumFrameBytes = maximumFrameBytes
    }

    public var bufferedByteCount: Int { buffer.count }

    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }

    public mutating func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        var frames: [Data] = []

        while true {
            guard let start = marker([0xff, 0xd8], from: buffer.startIndex) else {
                preservePossibleStartMarker()
                return frames
            }
            if start > buffer.startIndex {
                buffer.removeSubrange(buffer.startIndex..<start)
            }
            guard let endStart = marker([0xff, 0xd9], from: buffer.index(buffer.startIndex, offsetBy: 2)) else {
                if buffer.count > maximumFrameBytes {
                    reset()
                    throw JPEGFrameParserError.frameTooLarge(limit: maximumFrameBytes)
                }
                return frames
            }
            let end = buffer.index(endStart, offsetBy: 2)
            let frame = Data(buffer[..<end])
            guard frame.count <= maximumFrameBytes else {
                buffer.removeSubrange(..<end)
                throw JPEGFrameParserError.frameTooLarge(limit: maximumFrameBytes)
            }
            frames.append(frame)
            buffer.removeSubrange(..<end)
        }
    }

    private func marker(_ bytes: [UInt8], from index: Data.Index) -> Data.Index? {
        guard buffer.count >= bytes.count, index < buffer.endIndex else { return nil }
        return buffer[index...].firstRange(of: Data(bytes))?.lowerBound
    }

    private mutating func preservePossibleStartMarker() {
        let keepTrailingFF = buffer.last == 0xff
        buffer.removeAll(keepingCapacity: true)
        if keepTrailingFF { buffer.append(0xff) }
    }
}

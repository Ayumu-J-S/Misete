import Foundation

struct ProcessOutputBuffer {
    private let maximumBufferedBytes: Int
    private let maximumLineBytes: Int
    private var bytes = Data()
    private var discardingOversizedLine = false

    init(maximumBufferedBytes: Int = 64 * 1_024, maximumLineBytes: Int = 4 * 1_024) {
        self.maximumBufferedBytes = maximumBufferedBytes
        self.maximumLineBytes = maximumLineBytes
    }

    mutating func append(_ data: Data) -> [String] {
        var incoming = Data(data.prefix(maximumBufferedBytes))
        if discardingOversizedLine {
            guard let newline = incoming.firstIndex(of: 0x0a) else { return [] }
            incoming.removeSubrange(...newline)
            discardingOversizedLine = false
        }
        bytes.append(incoming)
        if bytes.count > maximumBufferedBytes {
            bytes.removeAll(keepingCapacity: true)
            discardingOversizedLine = true
            return []
        }

        var lines: [String] = []
        while let newline = bytes.firstIndex(of: 0x0a) {
            let lineData = bytes[..<newline].prefix(maximumLineBytes)
            bytes.removeSubrange(...newline)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line)
            }
        }
        if bytes.count > maximumLineBytes {
            bytes.removeAll(keepingCapacity: true)
            discardingOversizedLine = true
        }
        return lines
    }
}

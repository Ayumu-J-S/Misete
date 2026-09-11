import Foundation
import XCTest
@testable import MiseteReceiver

final class ProcessOutputBufferTests: XCTestCase {
    func testEmitsOnlyCompleteLinesAcrossChunks() {
        var buffer = ProcessOutputBuffer(maximumBufferedBytes: 64, maximumLineBytes: 32)
        XCTAssertEqual(buffer.append(Data("advertised Air".utf8)), [])
        XCTAssertEqual(buffer.append(Data("Play service\nnext\npartial".utf8)), ["advertised AirPlay service", "next"])
    }

    func testBoundsLongPartialLine() {
        var buffer = ProcessOutputBuffer(maximumBufferedBytes: 32, maximumLineBytes: 8)
        XCTAssertEqual(buffer.append(Data(repeating: 65, count: 1_000)), [])
        XCTAssertEqual(buffer.append(Data("ok\n".utf8)), [])
        XCTAssertEqual(buffer.append(Data("ready\n".utf8)), ["ready"])
    }
}

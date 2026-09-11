import XCTest
@testable import MiseteCore

final class JPEGFrameParserTests: XCTestCase {
    private let frameA = Data([0xff, 0xd8, 1, 2, 0xff, 0xd9])
    private let frameB = Data([0xff, 0xd8, 3, 4, 5, 0xff, 0xd9])

    func testHandlesFragmentationAndMultipleFrames() throws {
        var parser = JPEGFrameParser(maximumFrameBytes: 64)
        XCTAssertEqual(try parser.append(Data([9, 0xff])), [])
        XCTAssertEqual(try parser.append(Data([0xd8, 1, 2, 0xff])), [])
        XCTAssertEqual(try parser.append(Data([0xd9]) + frameB), [frameA, frameB])
    }

    func testResetDropsPartialFrame() throws {
        var parser = JPEGFrameParser(maximumFrameBytes: 64)
        _ = try parser.append(frameA.prefix(4))
        parser.reset()
        XCTAssertEqual(try parser.append(frameB), [frameB])
    }

    func testRejectsOversizedFrameAndRecovers() throws {
        var parser = JPEGFrameParser(maximumFrameBytes: 8)
        XCTAssertThrowsError(try parser.append(Data([0xff, 0xd8]) + Data(repeating: 7, count: 8)))
        XCTAssertEqual(try parser.append(frameA), [frameA])
    }

    func testKeepsSplitStartMarkerWithoutGrowingJunk() throws {
        var parser = JPEGFrameParser(maximumFrameBytes: 8)
        XCTAssertEqual(try parser.append(Data(repeating: 1, count: 100) + Data([0xff])), [])
        XCTAssertLessThanOrEqual(parser.bufferedByteCount, 1)
        XCTAssertEqual(try parser.append(Data([0xd8, 1, 0xff, 0xd9])), [Data([0xff, 0xd8, 1, 0xff, 0xd9])])
    }

    func testDropsJunkBeforeACompleteFrame() throws {
        var parser = JPEGFrameParser(maximumFrameBytes: 16)
        XCTAssertEqual(try parser.append(Data([1, 2, 3]) + frameA), [frameA])
        XCTAssertEqual(parser.bufferedByteCount, 0)
    }
}

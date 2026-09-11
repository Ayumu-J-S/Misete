import Foundation
import XCTest
@testable import MiseteCore

final class VideoWindowGeometryTests: XCTestCase {
    func testLandscapeUsesCurrentVideoHeightAndSourceAspectRatio() throws {
        let result = try XCTUnwrap(VideoWindowGeometry.fittedFrame(
            windowFrame: CGRect(x: 100, y: 100, width: 500, height: 700),
            videoSize: CGSize(width: 4, height: 3),
            chromeHeight: 100,
            visibleFrame: CGRect(x: -1_000, y: 0, width: 3_000, height: 1_200)
        ))

        assertRect(result, equals: CGRect(x: -50, y: 100, width: 800, height: 700))
    }

    func testPortraitRotationKeepsTopCenterAndVideoHeight() throws {
        let result = try XCTUnwrap(VideoWindowGeometry.fittedFrame(
            windowFrame: CGRect(x: 100, y: 100, width: 800, height: 700),
            videoSize: CGSize(width: 3, height: 4),
            chromeHeight: 100,
            visibleFrame: CGRect(x: 0, y: 0, width: 1_500, height: 1_000)
        ))

        assertRect(result, equals: CGRect(x: 275, y: 100, width: 450, height: 700))
    }

    func testMinimumVideoWidthScalesPortraitVideoWhenSpaceAllows() throws {
        let result = try XCTUnwrap(VideoWindowGeometry.fittedFrame(
            windowFrame: CGRect(x: 200, y: 100, width: 600, height: 700),
            videoSize: CGSize(width: 1, height: 2),
            chromeHeight: 80,
            visibleFrame: CGRect(x: 0, y: 0, width: 1_400, height: 1_100)
        ))

        assertRect(result, equals: CGRect(x: 320, y: 0, width: 360, height: 800))
    }

    func testUltrawideVideoScalesDownToVisibleWidth() throws {
        let result = try XCTUnwrap(VideoWindowGeometry.fittedFrame(
            windowFrame: CGRect(x: 200, y: 100, width: 600, height: 700),
            videoSize: CGSize(width: 32, height: 9),
            chromeHeight: 100,
            visibleFrame: CGRect(x: 0, y: 0, width: 1_200, height: 800)
        ))

        assertRect(result, equals: CGRect(x: 0, y: 362.5, width: 1_200, height: 437.5))
    }

    func testScreenClampMayGoBelowMinimumWidthAndConstrainsOrigin() throws {
        let visible = CGRect(x: 100, y: 50, width: 800, height: 600)
        let result = try XCTUnwrap(VideoWindowGeometry.fittedFrame(
            windowFrame: CGRect(x: 2_000, y: 1_000, width: 500, height: 700),
            videoSize: CGSize(width: 1, height: 2),
            chromeHeight: 100,
            visibleFrame: visible
        ))

        assertRect(result, equals: CGRect(x: 650, y: 50, width: 250, height: 600))
        XCTAssertTrue(visible.contains(result))
    }

    func testRejectsInvalidOrImpossibleGeometry() {
        let validWindow = CGRect(x: 0, y: 0, width: 500, height: 500)
        let validVideo = CGSize(width: 4, height: 3)
        let validScreen = CGRect(x: 0, y: 0, width: 1_000, height: 800)

        XCTAssertNil(VideoWindowGeometry.fittedFrame(windowFrame: validWindow, videoSize: .zero, chromeHeight: 40, visibleFrame: validScreen))
        XCTAssertNil(VideoWindowGeometry.fittedFrame(windowFrame: validWindow, videoSize: CGSize(width: CGFloat.infinity, height: 3), chromeHeight: 40, visibleFrame: validScreen))
        XCTAssertNil(VideoWindowGeometry.fittedFrame(windowFrame: CGRect(x: CGFloat.nan, y: 0, width: 500, height: 500), videoSize: validVideo, chromeHeight: 40, visibleFrame: validScreen))
        XCTAssertNil(VideoWindowGeometry.fittedFrame(windowFrame: validWindow, videoSize: validVideo, chromeHeight: -1, visibleFrame: validScreen))
        XCTAssertNil(VideoWindowGeometry.fittedFrame(windowFrame: validWindow, videoSize: validVideo, chromeHeight: 800, visibleFrame: validScreen))
        XCTAssertNil(VideoWindowGeometry.fittedFrame(windowFrame: validWindow, videoSize: validVideo, chromeHeight: 40, visibleFrame: .zero))
    }

    private func assertRect(_ actual: CGRect, equals expected: CGRect, accuracy: CGFloat = 0.001) {
        XCTAssertEqual(actual.origin.x, expected.origin.x, accuracy: accuracy)
        XCTAssertEqual(actual.origin.y, expected.origin.y, accuracy: accuracy)
        XCTAssertEqual(actual.width, expected.width, accuracy: accuracy)
        XCTAssertEqual(actual.height, expected.height, accuracy: accuracy)
    }
}

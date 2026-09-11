import Foundation
import XCTest
@testable import MiseteReceiver

final class ExecutableResolverTests: XCTestCase {
    func testExplicitExecutableWins() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: temporary.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.path)
        defer { try? FileManager.default.removeItem(at: temporary) }

        XCTAssertEqual(try ExecutableResolver.uxPlay(explicit: temporary, workingDirectory: URL(fileURLWithPath: "/missing")), temporary)
    }

    func testRejectsMissingExplicitExecutable() {
        XCTAssertThrowsError(try ExecutableResolver.uxPlay(explicit: URL(fileURLWithPath: "/missing/uxplay")))
    }

    func testProcessEnvironmentDisablesImplicitUxPlayConfig() {
        let environment = ExecutableResolver.processEnvironment(base: ["PATH": "/bin", "UXPLAYRC": "/tmp/unsafe"])
        XCTAssertEqual(environment["UXPLAYRC"], "/dev/null")
        XCTAssertTrue(environment["PATH"]?.hasSuffix(":/bin") == true)
    }
}

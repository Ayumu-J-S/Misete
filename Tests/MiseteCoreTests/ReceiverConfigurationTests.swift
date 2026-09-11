import XCTest
@testable import MiseteCore

final class ReceiverConfigurationTests: XCTestCase {
    func testDefaultsBuildExpectedUxPlayArguments() throws {
        let configuration = try ReceiverConfiguration(
            framePort: 49152,
            requiresPairing: true,
            pairingPIN: "0427",
            registrationFile: URL(fileURLWithPath: "/tmp/Misete Clients")
        )

        XCTAssertEqual(configuration.receiverName, "Misete")
        XCTAssertEqual(configuration.airPlayPorts, [35000, 35001, 35002])
        XCTAssertEqual(configuration.uxPlayArguments, [
            "-n", "Misete", "-nh", "-p", "35000,35001,35002",
            "-pin", "0427", "-reg", "/tmp/Misete Clients",
            "-d", "1",
            "-vsync", "no",
            "-vs", "jpegenc quality=85 ! tcpclientsink host=127.0.0.1 port=49152 sync=false"
        ])
    }

    func testDefaultDoesNotRequestAnyAuthentication() throws {
        let configuration = try ReceiverConfiguration(framePort: 49152)
        XCTAssertFalse(configuration.uxPlayArguments.contains("-pin"))
        XCTAssertFalse(configuration.uxPlayArguments.contains("-reg"))
        XCTAssertFalse(configuration.uxPlayArguments.contains("-pw"))
    }

    func testPairingOptInRequestsPerClientRandomCode() throws {
        let configuration = try ReceiverConfiguration(
            framePort: 49152,
            requiresPairing: true,
            registrationFile: URL(fileURLWithPath: "/tmp/r")
        )
        XCTAssertEqual(Array(configuration.uxPlayArguments.prefix(7)), [
            "-n", "Misete", "-nh", "-p", "35000,35001,35002", "-pin", "-reg"
        ])
    }

    func testRejectsInvalidNamesPortsAndPINs() {
        XCTAssertThrowsError(try ReceiverConfiguration(receiverName: "   ", framePort: 4000))
        XCTAssertThrowsError(try ReceiverConfiguration(receiverName: String(repeating: "a", count: 46), framePort: 4000))
        XCTAssertThrowsError(try ReceiverConfiguration(receiverName: "Bad\0Name", framePort: 4000))
        XCTAssertNoThrow(try ReceiverConfiguration(receiverName: String(repeating: "é", count: 22), framePort: 4000))
        XCTAssertThrowsError(try ReceiverConfiguration(airPlayPorts: [80, 35001, 35002], framePort: 4000))
        XCTAssertThrowsError(try ReceiverConfiguration(airPlayPorts: [35000, 35000, 35002], framePort: 4000))
        XCTAssertThrowsError(try ReceiverConfiguration(framePort: 35000))
        XCTAssertThrowsError(try ReceiverConfiguration(framePort: 4000, requiresPairing: true, pairingPIN: "0000", registrationFile: URL(fileURLWithPath: "/tmp/r")))
        XCTAssertThrowsError(try ReceiverConfiguration(framePort: 4000, requiresPairing: true, pairingPIN: "123", registrationFile: URL(fileURLWithPath: "/tmp/r")))
        XCTAssertThrowsError(try ReceiverConfiguration(framePort: 4000, requiresPairing: true, pairingPIN: "１２３４", registrationFile: URL(fileURLWithPath: "/tmp/r")))
        XCTAssertThrowsError(try ReceiverConfiguration(airPlayPorts: [35000, 35001], framePort: 4000))
        XCTAssertThrowsError(try ReceiverConfiguration(framePort: 70000))
        XCTAssertThrowsError(try ReceiverConfiguration(framePort: 4000, requiresPairing: true, registrationFile: URL(string: "https://example.com/r")!))
        XCTAssertThrowsError(try ReceiverConfiguration(framePort: 4000, requiresPairing: true))
    }

    func testMutedConfigurationDisablesAudioAndErrorsAreActionable() throws {
        let configuration = try ReceiverConfiguration(framePort: 4000, muted: true)
        XCTAssertEqual(Array(configuration.uxPlayArguments.suffix(2)), ["-as", "0"])
        let errors: [ReceiverConfigurationError] = [
            .invalidName, .invalidPort(80), .duplicatePorts, .invalidPIN, .invalidRegistrationFile
        ]
        XCTAssertTrue(errors.allSatisfy { !($0.errorDescription ?? "").isEmpty })
    }
}

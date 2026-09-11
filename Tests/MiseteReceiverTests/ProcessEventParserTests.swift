import XCTest
@testable import MiseteReceiver

final class ProcessEventParserTests: XCTestCase {
    func testRecognizesOnlyExpectedSafeEvents() {
        XCTAssertEqual(ProcessEventParser.event(for: "DEBUG register_dnssd: advertised AirPlay service"), .advertised)
        XCTAssertEqual(ProcessEventParser.event(for: "*** CLIENT MUST NOW ENTER PIN = \"0427\" AS AIRPLAY PASSWORD"), .pairingPIN("0427"))
        XCTAssertEqual(ProcessEventParser.event(for: "registered new client: private details"), .clientRegistered)
        XCTAssertNil(ProcessEventParser.event(for: "PIN = \"１２３４\""))
        XCTAssertNil(ProcessEventParser.event(for: "deviceID = AA:BB:CC"))
    }
}

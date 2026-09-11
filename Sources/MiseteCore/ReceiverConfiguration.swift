import Foundation

public enum ReceiverConfigurationError: Error, Equatable, LocalizedError {
    case invalidName
    case invalidPort(Int)
    case duplicatePorts
    case invalidPIN
    case invalidRegistrationFile

    public var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Receiver name must be 1–45 UTF-8 bytes so it fits in Bonjour."
        case .invalidPort(let port):
            return "Port \(port) is outside UxPlay's supported range (1024–65535)."
        case .duplicatePorts:
            return "AirPlay ports must be distinct."
        case .invalidPIN:
            return "Pairing PIN must contain four digits from 0001 through 9999."
        case .invalidRegistrationFile:
            return "A pairing registration file is required."
        }
    }
}

public struct ReceiverConfiguration: Equatable, Sendable {
    public static let defaultAirPlayPorts = [35000, 35001, 35002]
    public static let maximumReceiverNameBytes = 45

    public let receiverName: String
    public let airPlayPorts: [Int]
    public let framePort: Int
    public let requiresPairing: Bool
    public let pairingPIN: String?
    public let registrationFile: URL?
    public let muted: Bool

    public init(
        receiverName: String = "Misete",
        airPlayPorts: [Int] = ReceiverConfiguration.defaultAirPlayPorts,
        framePort: Int,
        requiresPairing: Bool = false,
        pairingPIN: String? = nil,
        registrationFile: URL? = nil,
        muted: Bool = false
    ) throws {
        let trimmedName = receiverName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              trimmedName.lengthOfBytes(using: .utf8) <= Self.maximumReceiverNameBytes,
              !trimmedName.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw ReceiverConfigurationError.invalidName
        }
        guard airPlayPorts.count == 3 else {
            throw ReceiverConfigurationError.invalidPort(0)
        }
        let allPorts = airPlayPorts + [framePort]
        for port in allPorts {
            guard (1024...65535).contains(port) else {
                throw ReceiverConfigurationError.invalidPort(port)
            }
        }
        guard Set(allPorts).count == allPorts.count else {
            throw ReceiverConfigurationError.duplicatePorts
        }
        if requiresPairing, let pairingPIN {
            guard pairingPIN.count == 4,
                  pairingPIN.utf8.allSatisfy({ (48...57).contains($0) }),
                  pairingPIN != "0000" else {
                throw ReceiverConfigurationError.invalidPIN
            }
        }
        if requiresPairing {
            guard let registrationFile,
                  registrationFile.isFileURL,
                  !registrationFile.path.isEmpty else {
                throw ReceiverConfigurationError.invalidRegistrationFile
            }
        }

        self.receiverName = trimmedName
        self.airPlayPorts = airPlayPorts
        self.framePort = framePort
        self.requiresPairing = requiresPairing
        self.pairingPIN = requiresPairing ? pairingPIN : nil
        self.registrationFile = requiresPairing ? registrationFile : nil
        self.muted = muted
    }

    public var videoSink: String {
        "jpegenc quality=85 ! tcpclientsink host=127.0.0.1 port=\(framePort) sync=false"
    }

    public var uxPlayArguments: [String] {
        var arguments = [
            "-n", receiverName,
            "-nh",
            "-p", airPlayPorts.map(String.init).joined(separator: ",")
        ]
        if requiresPairing, let registrationFile {
            arguments.append("-pin")
            if let pairingPIN { arguments.append(pairingPIN) }
            arguments += ["-reg", registrationFile.path]
        }
        arguments += [
            "-d", "1",
            "-vsync", "no",
            "-vs", videoSink
        ]
        if muted {
            arguments += ["-as", "0"]
        }
        return arguments
    }
}

import Foundation

public enum ProbeError: Error, Equatable, CustomStringConvertible {
    case invalidConfiguration(String)
    case crossProfileMove
    case staleGeneration
    public var description: String {
        switch self {
        case .invalidConfiguration(let message): message
        case .crossProfileMove: "Cross-profile move rejected; copy the URL explicitly instead."
        case .staleGeneration: "Stale browser event rejected."
        }
    }
}

public struct ProbeProfile: Codable, Equatable, Sendable {
    public let name: String
    public let storeID: UUID
    public init(name: String, storeID: UUID) { self.name = name; self.storeID = storeID }
}

public struct ProbeSpace: Equatable, Sendable {
    public let name: String
    public let profile: ProbeProfile
    public init(name: String, profile: ProbeProfile) { self.name = name; self.profile = profile }
}

public struct ProbeConfiguration: Sendable {
    public let originA: URL
    public let originB: URL
    public let profileA: ProbeProfile
    public let profileB: ProbeProfile
    public let disposableStoreID: UUID
    public let runToken: String

    public init(originA: URL, originB: URL, storeA: UUID, storeB: UUID,
                disposableStoreID: UUID, runToken: String) throws {
        let zero = UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))
        guard Set([storeA, storeB, disposableStoreID]).count == 3,
              ![storeA, storeB, disposableStoreID].contains(zero) else {
            throw ProbeError.invalidConfiguration("Probe stores must be distinct non-zero UUIDs.")
        }
        guard Self.allowedOrigin(originA), Self.allowedOrigin(originB),
              originA.port != originB.port else {
            throw ProbeError.invalidConfiguration("Use two distinct explicit HTTP loopback ports.")
        }
        guard !runToken.isEmpty, runToken.count <= 80,
              runToken.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else {
            throw ProbeError.invalidConfiguration("Invalid local fixture token.")
        }
        self.originA = originA; self.originB = originB
        profileA = ProbeProfile(name: "A", storeID: storeA)
        profileB = ProbeProfile(name: "B", storeID: storeB)
        self.disposableStoreID = disposableStoreID; self.runToken = runToken
    }

    private static func allowedOrigin(_ url: URL) -> Bool {
        url.scheme == "http" && url.host == "127.0.0.1" && url.port != nil
            && url.user == nil && url.password == nil
            && (url.path.isEmpty || url.path == "/") && url.query == nil && url.fragment == nil
    }

    public var spaces: [ProbeSpace] {
        [ProbeSpace(name: "A1", profile: profileA), ProbeSpace(name: "A2", profile: profileA),
         ProbeSpace(name: "B1", profile: profileB)]
    }
}

public struct BrowserIdentity: Equatable, Sendable {
    public let tabID: UUID
    public let profileID: UUID
    public let generation: UUID
    public init(tabID: UUID = UUID(), profileID: UUID, generation: UUID = UUID()) {
        self.tabID = tabID; self.profileID = profileID; self.generation = generation
    }
    public func accepts(_ other: BrowserIdentity) -> Bool { self == other }
    public func validateMove(to profileID: UUID) throws {
        guard self.profileID == profileID else { throw ProbeError.crossProfileMove }
    }
}

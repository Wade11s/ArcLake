import Foundation

public protocol DomainIdentifierTag: Sendable {}

public struct DomainIdentifier<Tag: DomainIdentifierTag>: Hashable, Codable, Sendable,
  CustomStringConvertible, Comparable
{
  public let rawValue: UUID

  public init(_ rawValue: UUID = UUID()) {
    self.rawValue = rawValue
  }

  public init?(uuidString: String) {
    guard let value = UUID(uuidString: uuidString) else { return nil }
    rawValue = value
  }

  public var description: String { rawValue.uuidString.lowercased() }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue.uuidString < rhs.rawValue.uuidString
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    guard let uuid = UUID(uuidString: value) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid UUID identifier")
    }
    rawValue = uuid
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue.uuidString.lowercased())
  }
}

public enum ProfileTag: DomainIdentifierTag {}
public enum SpaceTag: DomainIdentifierTag {}
public enum RootTag: DomainIdentifierTag {}
public enum ItemTag: DomainIdentifierTag {}
public enum TabTag: DomainIdentifierTag {}
public enum WindowTag: DomainIdentifierTag {}
public enum ArchiveTag: DomainIdentifierTag {}
public enum HistoryTag: DomainIdentifierTag {}
public enum RouteTag: DomainIdentifierTag {}
public enum PendingOperationTag: DomainIdentifierTag {}
public enum GenerationTag: DomainIdentifierTag {}
public enum HostTag: DomainIdentifierTag {}

public typealias ProfileID = DomainIdentifier<ProfileTag>
public typealias SpaceID = DomainIdentifier<SpaceTag>
public typealias RootID = DomainIdentifier<RootTag>
public typealias ItemID = DomainIdentifier<ItemTag>
public typealias TabID = DomainIdentifier<TabTag>
public typealias WindowID = DomainIdentifier<WindowTag>
public typealias ArchiveID = DomainIdentifier<ArchiveTag>
public typealias HistoryID = DomainIdentifier<HistoryTag>
public typealias RouteRuleID = DomainIdentifier<RouteTag>
public typealias PendingOperationID = DomainIdentifier<PendingOperationTag>
public typealias GenerationID = DomainIdentifier<GenerationTag>
public typealias BrowserHostID = DomainIdentifier<HostTag>

extension UUID {
  public static let domainZero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}

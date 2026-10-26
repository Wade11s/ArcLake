import Testing

@testable import ArcLakeCore

@Suite("Workspace bootstrap")
struct BootstrapTests {
  @Test("T06 fresh state has exactly one Default Profile and Space")
  func freshStateHasExactlyOneDefaultProfileAndSpace() throws {
    let state = CoreFixtures.initial()
    #expect(state.profiles.count == 1)
    #expect(state.spaces.count == 1)
    #expect(state.profiles.first?.name == "Default")
    #expect(state.spaces.first?.name == "Default")
    #expect(state.roots.count == 3)
    #expect(
      Set(state.roots.map(\.kind))
        == Set([.profileFavorites, .spacePinned, .spaceToday]))
    #expect(state.profiles[0].websiteStoreID != .domainZero)
    try WorkspaceValidator.validate(state)
  }
}

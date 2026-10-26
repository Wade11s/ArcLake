import XCTest
@testable import M0Core

final class ProbeConfigurationTests: XCTestCase {
    func testSpacesShareOnlyIntendedProfile() throws {
        let c = try config()
        XCTAssertEqual(c.spaces.map(\.name), ["A1", "A2", "B1"])
        XCTAssertEqual(c.spaces[0].profile.storeID, c.spaces[1].profile.storeID)
        XCTAssertNotEqual(c.spaces[0].profile.storeID, c.spaces[2].profile.storeID)
    }
    func testInvalidStoreIDsAreRejected() {
        let id = UUID()
        XCTAssertThrowsError(try config(a: id, b: id))
        let zero = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        XCTAssertThrowsError(try config(a: zero))
    }
    func testExternalOrSameOriginsAreRejected() {
        XCTAssertThrowsError(try config(originA: "https://example.com"))
        XCTAssertThrowsError(try config(originA: "http://localhost:18181"))
        XCTAssertThrowsError(try config(originB: "http://127.0.0.1:18181"))
        XCTAssertThrowsError(try config(originA: "http://user@127.0.0.1:18181"))
    }
    func testStableCodableProfile() throws {
        let p = try config().profileA
        XCTAssertEqual(try JSONDecoder().decode(ProbeProfile.self, from: JSONEncoder().encode(p)), p)
    }
    func testOwnershipAndStaleEvents() throws {
        let a = UUID(), b = UUID()
        let current = BrowserIdentity(profileID: a)
        try current.validateMove(to: a)
        XCTAssertThrowsError(try current.validateMove(to: b))
        XCTAssertTrue(current.accepts(current))
        XCTAssertFalse(current.accepts(BrowserIdentity(tabID: current.tabID, profileID: a)))
        XCTAssertFalse(current.accepts(BrowserIdentity(tabID: current.tabID, profileID: b,
                                                     generation: current.generation)))
    }
    private func config(a: UUID = UUID(), b: UUID = UUID(),
                        originA: String = "http://127.0.0.1:18181",
                        originB: String = "http://127.0.0.1:18182") throws -> ProbeConfiguration {
        try ProbeConfiguration(originA: URL(string: originA)!, originB: URL(string: originB)!,
                               storeA: a, storeB: b, disposableStoreID: UUID(), runToken: "test-run")
    }
}

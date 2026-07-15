import Foundation
import XCTest
@testable import GitHubBarCore

final class SettingsStoreTests: XCTestCase {
    func testRepositoryScopePersistsInUserDefaults() async {
        let suiteName = "GitHubBarCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSettingsStore(defaults: defaults)
        let expected = AppSettings(
            selectedLogin: "FranciscoMoretti",
            repositoryScope: .selected(["REPO-1"])
        )

        await store.save(expected)

        XCTAssertEqual(await store.load(), expected)
    }
}

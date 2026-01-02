import XCTest
import patrol

final class RunnerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRunner() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Patrol handles the actual test execution
        // This is just a placeholder that Patrol uses to run Dart tests
    }
}


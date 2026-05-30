import XCTest
@testable import CloudView

final class BackendConfigTests: XCTestCase {

    func testReportScanURLEndpointPath() {
        XCTAssertEqual(BackendConfig.reportScanURL.path, "/api/report-scan")
    }

    func testRegisterDeviceURLEndpointPath() {
        XCTAssertEqual(BackendConfig.registerDeviceURL.path, "/api/register-device")
    }

    func testRegionalActivityURLEndpointPath() {
        XCTAssertEqual(BackendConfig.regionalActivityURL.path, "/api/regional-activity")
    }

    func testAllEndpointsShareTheSameHost() {
        let hosts = [
            BackendConfig.reportScanURL.host,
            BackendConfig.registerDeviceURL.host,
            BackendConfig.regionalActivityURL.host,
        ]
        let unique = Set(hosts.compactMap { $0 })
        XCTAssertEqual(unique.count, 1, "All endpoints must point at the same host")
    }

    func testEndpointsUseHTTPS() {
        XCTAssertEqual(BackendConfig.reportScanURL.scheme, "https")
        XCTAssertEqual(BackendConfig.registerDeviceURL.scheme, "https")
        XCTAssertEqual(BackendConfig.regionalActivityURL.scheme, "https")
    }
}

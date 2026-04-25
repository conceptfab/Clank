import XCTest
@testable import Clank

final class AmplitudeWindowTests: XCTestCase {
    func test_pushOverflow_evictsOldestInOrder() {
        let window = AmplitudeWindow(capacity: 3)
        window.push(1)
        window.push(2)
        window.push(3)
        window.push(4)
        XCTAssertEqual(window.snapshot(), [2, 3, 4])
    }

    func test_medianAndMAD_matchNaiveImplementation() {
        let values: [Double] = [0.10, 0.05, 0.30, 0.02, 0.07, 0.04, 0.20, 0.06, 0.08, 0.03]
        let window = AmplitudeWindow(capacity: values.count)
        for v in values { window.push(v) }
        let stats = window.medianAndMAD()

        let sorted = values.sorted()
        let expectedMedian = sorted[sorted.count / 2]
        let deviations = sorted.map { abs($0 - expectedMedian) }.sorted()
        let expectedMAD = deviations[deviations.count / 2]

        XCTAssertEqual(stats.median, expectedMedian, accuracy: 1e-12)
        XCTAssertEqual(stats.mad, expectedMAD, accuracy: 1e-12)
    }

    func test_count_reportsHowFullTheWindowIs() {
        let window = AmplitudeWindow(capacity: 4)
        XCTAssertEqual(window.count, 0)
        window.push(0.1)
        window.push(0.2)
        XCTAssertEqual(window.count, 2)
        window.push(0.3); window.push(0.4); window.push(0.5)
        XCTAssertEqual(window.count, 4)
    }
}

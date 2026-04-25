import Foundation

final class AmplitudeWindow {
    struct Stats {
        let median: Double
        let mad: Double
    }

    private var storage: [Double]
    private var writeIndex = 0
    private var filled = 0
    private let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        self.storage = Array(repeating: 0, count: capacity)
    }

    var count: Int { filled }

    func push(_ value: Double) {
        storage[writeIndex] = value
        writeIndex = (writeIndex + 1) % capacity
        if filled < capacity { filled += 1 }
    }

    func snapshot() -> [Double] {
        if filled < capacity {
            return Array(storage[0..<filled])
        }
        return Array(storage[writeIndex..<capacity]) + Array(storage[0..<writeIndex])
    }

    func medianAndMAD() -> Stats {
        precondition(filled > 0, "medianAndMAD on empty window")
        var working = snapshot()
        working.sort()
        let median = working[working.count / 2]
        for i in working.indices {
            working[i] = abs(working[i] - median)
        }
        working.sort()
        let mad = working[working.count / 2]
        return Stats(median: median, mad: mad)
    }
}

package proj_iterimport

class CountIterator {
    let limit: Int64
    init(limit: Int64) {
        this.limit = limit
    }
    var current = 0
    func hasNext(): Bool {
        return current < limit
    }
    func next(): Int64 {
        let v = current
        current += 1
        return v
    }
}

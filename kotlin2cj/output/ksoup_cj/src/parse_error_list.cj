package ksoup_cj

class ParseErrorList <: MutableList {
    let initialCapacity: Int64
    let maxSize: Int64
    init(initialCapacity: Int64, maxSize: Int64) {
        this.initialCapacity = initialCapacity
        this.maxSize = maxSize
    }
    init(copy: ParseErrorList) {
        this(copy.initialCapacity, copy.maxSize)
    }
    func canAddError(): Bool {
        return size < maxSize
    }
    func clone(): ParseErrorList {
        return { it =>
            let _also_it = ParseErrorList(initialCapacity, maxSize)
            let _it = _also_it
            _it.add(all: this)
            return _also_it
        }()
    }
    static let INITIAL_CAPACITY = 16
    static func noTracking(): ParseErrorList {
        return ParseErrorList(0, 0)
    }
    static func tracking(maxSize: Int64): ParseErrorList {
        return ParseErrorList(ParseErrorList.INITIAL_CAPACITY, maxSize)
    }
}

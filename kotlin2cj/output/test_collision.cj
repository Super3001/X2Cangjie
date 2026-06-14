class Token {
    var _startPos = 0
    var _endPos = -1
    func startPos(): Int64 {
        return _startPos
    }
    func startPos(pos: Int64) {
        _startPos = pos
    }
    func endPos(): Int64 {
        return _endPos
    }
    func endPos(pos: Int64) {
        _endPos = pos
    }
}

class Safelist {
    var _preserveRelativeLinks = false
    func preserveRelativeLinks(preserve: Bool): Safelist {
        _preserveRelativeLinks = preserve
        return this
    }
    func preserveRelativeLinks(): Bool {
        return _preserveRelativeLinks
    }
}

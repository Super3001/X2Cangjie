package ksoup_cj

class Range <: ToString {
    let _start: Position
    let _end: Position
    init(start: Position, end: Position) {
        this._start = start
        this._end = end
    }
    func start(): Position {
        return _start
    }
    func end(): Position {
        return _end
    }
    func startPos(): Int64 {
        return start.pos
    }
    func endPos(): Int64 {
        return end.pos
    }
    func isTracked(): Bool {
        return this != Range.Untracked()
    }
    func isImplicit(): Bool {
        if (!isTracked()) {
            return false
        }
        return start == end
    }
    public override func toString(): String {
        return "${start}-${end}"
    }
    static let UntrackedPos = Position(-1, -1, -1)
    static let Untracked = Range(Range.UntrackedPos(), Range.UntrackedPos())
    static func of(node: Node, start: Bool): Range {
        let key: String = if (start) {
            SharedConstants.RangeKey
        } else {
            SharedConstants.EndRangeKey
        }
        if (!node.hasAttributes()) {
            return Range.Untracked()
        }
        let range = node.attributes().userData(key)
        return if (let Some(rangeValue) <- range) {
            let range = rangeValue
            (range as Range)
        } else {
            Range.Untracked()
        }
    }
}

class Position <: ToString {
    let _pos: Int64
    let _lineNumber: Int64
    let _columnNumber: Int64
    init(pos: Int64, lineNumber: Int64, columnNumber: Int64) {
        this._pos = pos
        this._lineNumber = lineNumber
        this._columnNumber = columnNumber
    }
    func pos(): Int64 {
        return _pos
    }
    func lineNumber(): Int64 {
        return _lineNumber
    }
    func columnNumber(): Int64 {
        return _columnNumber
    }
    func isTracked(): Bool {
        return this != UntrackedPos
    }
    public override func toString(): String {
        return "${lineNumber},${columnNumber}:${pos}"
    }
}

class AttributeRange <: ToString {
    let _nameRange: Range
    let _valueRange: Range
    init(nameRange: Range, valueRange: Range) {
        this._nameRange = nameRange
        this._valueRange = valueRange
    }
    func nameRange(): Range {
        return _nameRange
    }
    func valueRange(): Range {
        return _valueRange
    }
    public override func toString(): String {
        let sb = StringUtil.borrowBuilder().append(nameRange).append(r'=').append(valueRange)
        return StringUtil.releaseBuilder(sb)
    }
    static func UntrackedAttr(): AttributeRange {
        return AttributeRange(Untracked, Untracked)
    }
}

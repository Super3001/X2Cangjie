package target_1g

class Range <: ToString {
    let start: Position
    let end: Position
    init(start: Position, end: Position) {
        this.start = start
        this.end = end
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
    static func UntrackedPos(): Position {
        return Position(-1, -1, -1)
    }
    static func Untracked(): Range {
        return Range(Range.UntrackedPos(), Range.UntrackedPos())
    }
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
    let pos: Int64
    let lineNumber: Int64
    let columnNumber: Int64
    init(pos: Int64, lineNumber: Int64, columnNumber: Int64) {
        this.pos = pos
        this.lineNumber = lineNumber
        this.columnNumber = columnNumber
    }
    func isTracked(): Bool {
        return this != UntrackedPos
    }
    public override func toString(): String {
        return "${lineNumber},${columnNumber}:${pos}"
    }
}

class AttributeRange <: ToString {
    let nameRange: Range
    let valueRange: Range
    init(nameRange: Range, valueRange: Range) {
        this.nameRange = nameRange
        this.valueRange = valueRange
    }
    public override func toString(): String {
        let sb = StringUtil.borrowBuilder().append(nameRange).append(r'=').append(valueRange)
        return StringUtil.releaseBuilder(sb)
    }
    static func UntrackedAttr(): AttributeRange {
        return AttributeRange(Untracked, Untracked)
    }
}

package target_1e

import std.collection.*
import std.deriving.*

@Derive[Equatable]
struct LineEndingMode <: ToString {
    let mode: Int64
    init(mode: Int64) {
        this.mode = mode
    }
    func contains(other: LineEndingMode): Bool {
        return (mode | other.mode) == mode
    }
    func plus(other: LineEndingMode): LineEndingMode {
        return LineEndingMode(mode | other.mode)
    }
    public override func toString(): String {
        return if ((this).mode == (LineEndingMode.CR()).mode) { "CR" } else if ((this).mode == (LineEndingMode.LF()).mode) { "LF" } else if ((this).mode == (LineEndingMode.CRLF()).mode) { "CRLF" } else { collectArrayList(LineEndingMode.values().iterator().filter({ it => this.contains(it) })).toString() }
    }
    static func CR(): LineEndingMode {
        return LineEndingMode(0b001)
    }
    static func LF(): LineEndingMode {
        return LineEndingMode(0b010)
    }
    static func CRLF(): LineEndingMode {
        return LineEndingMode(0b100)
    }
    static func Any(): LineEndingMode {
        return LineEndingMode(0b111)
    }
    static func values(): ArrayList<LineEndingMode> {
        return ArrayList([LineEndingMode.CR(), LineEndingMode.LF(), LineEndingMode.CRLF()])
    }
}

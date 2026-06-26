package target_1d

import std.convert.*

class ParseError <: ToString {
    let pos: Int64
    let cursorPos: String
    let errorMsg: String
    init(reader: CharacterReader, errorMsg: String) {
        pos = reader.pos()
        cursorPos = reader.posLineCol()
        this.errorMsg = errorMsg
    }
    init(pos: Int64, errorMsg: String) {
        this.pos = pos
        cursorPos = pos.toString()
        this.errorMsg = errorMsg
    }
    public override func toString(): String {
        return "<${cursorPos}>: ${errorMsg}"
    }
}

package test

class Token {
    var startPos = 0
    var endPos = -1

    fun startPos(): Int {
        return startPos
    }
    fun startPos(pos: Int) {
        startPos = pos
    }
    fun endPos(): Int {
        return endPos
    }
    fun endPos(pos: Int) {
        endPos = pos
    }
}

class Safelist {
    var preserveRelativeLinks = false

    fun preserveRelativeLinks(preserve: Boolean): Safelist {
        preserveRelativeLinks = preserve
        return this
    }
    fun preserveRelativeLinks(): Boolean {
        return preserveRelativeLinks
    }
}

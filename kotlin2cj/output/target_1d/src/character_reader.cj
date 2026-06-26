package target_1d

import std.collection.*
import std.convert.*

class CharacterReader <: AutoCloseable & ToString {
    var stringCache: ?Array<?String> = None
    var reader: ?Reader = None
    var charBuf: ?Array<Rune>
    var bufPos = 0
    var bufLength = 0
    var fillPoint = 0
    var consumed: Int64 = 0
    var bufMark = -1
    var _readFully = false
    var newlinePositions: ?ArrayList<Int64> = None
    var lineNumberOffset = 1
    init(reader: Reader) {
        this.reader = reader
        charBuf = CharacterReader.BufferPool().borrow()
        stringCache = CharacterReader.StringPool().borrow()
        bufferUp()
    }
    init(html: String) {
        this(StringReader(html))
    }
    func isClosed(): Bool {
        return reader.isNone()
    }
    public override func close() {
        try {
            reader?.close()
        } catch (ignored: IOException) {} finally {
            reader = None
            charBuf?.fill(Rune(UInt32(0)))
            if (let Some(it) <- charBuf) {
                CharacterReader.BufferPool().release(it)
            }
            charBuf = None
            if (let Some(it) <- stringCache) {
                CharacterReader.StringPool().release(it)
            }
            stringCache = None
        }
    }
    func bufferUp() {
        if ((_readFully || (bufPos < fillPoint)) || (bufMark != -1)) {
            return
        }
        doBufferUp()
    }
    func doBufferUp() {
        consumed += bufPos
        bufLength -= bufPos
        if (bufLength > 0) {
            charBuf?.copyInto(charBuf.getOrThrow(), 0, bufPos, bufPos + bufLength)
        }
        bufPos = 0
        while (bufLength < CharacterReader.BufferSize()) {
            try {
                let read = reader.getOrThrow().read(charBuf.getOrThrow(), bufLength, charBuf.getOrThrow().size - bufLength)
                if (read == -1) {
                    _readFully = true
                    break
                }
                if (read == 0) {
                    break
                }
                bufLength += read
            } catch (e: IOException) {
                throw UncheckedIOException(e)
            }
        }
        fillPoint = (if (bufLength < CharacterReader.RefillPoint()) { bufLength } else { CharacterReader.RefillPoint() })
        scanBufferForNewlines()
        lastIcSeq = None
    }
    func mark() {
        if ((bufLength - bufPos) < CharacterReader.RewindLimit) {
            fillPoint = 0
        }
        bufferUp()
        bufMark = bufPos
    }
    func unmark() {
        bufMark = -1
    }
    func rewindToMark() {
        if (bufMark == -1) {
            throw UncheckedIOException(IOException("Mark invalid"))
        }
        bufPos = bufMark
        unmark()
    }
    func pos(): Int64 {
        return consumed + bufPos
    }
    func readFully(): Bool {
        return _readFully
    }
    func trackNewlines(track: Bool) {
        if (track && (newlinePositions.isNone())) {
            newlinePositions = ArrayList<Int64>([CharacterReader.BufferSize() / 80])
            scanBufferForNewlines()
        } else if (!track) {
            newlinePositions = None
        }
    }
    func isTrackNewlines(): Bool {
        return newlinePositions.isSome()
    }
    func lineNumber(): Int64 {
        return lineNumber(pos())
    }
    func lineNumber(pos: Int64): Int64 {
        if (!isTrackNewlines()) {
            return 1
        }
        let i = lineNumIndex(pos)
        return if (i == -1) {
            lineNumberOffset
        } else {
            (i + lineNumberOffset) + 1
        }
    }
    func columnNumber(): Int64 {
        return columnNumber(pos())
    }
    func columnNumber(pos: Int64): Int64 {
        if (!isTrackNewlines()) {
            return pos + 1
        }
        let i = lineNumIndex(pos)
        return if (i == -1) {
            pos + 1
        } else {
            (pos - newlinePositions.getOrThrow()[i]) + 1
        }
    }
    func posLineCol(): String {
        return (lineNumber().toString() + ":") + columnNumber().toString()
    }
    func lineNumIndex(pos: Int64): Int64 {
        if (!isTrackNewlines()) {
            return 0
        }
        var i: Int64 = newlinePositions.getOrThrow().binarySearch(pos)
        if (i < -1) {
            i = (if (i < 0) { -(i) } else { i }) - 2
        }
        return i
    }
    func scanBufferForNewlines() {
        if (!isTrackNewlines()) {
            return
        }
        if (!(newlinePositions.getOrThrow().isEmpty())) {
            var index = lineNumIndex(consumed)
            if (index == -1) {
                index = 0
            }
            let linePos: Int64 = newlinePositions.getOrThrow()[index]
            lineNumberOffset += index
            newlinePositions.getOrThrow().clear()
            newlinePositions.getOrThrow().add(linePos)
        }
        for (i in bufPos..bufLength) {
            if (charBuf.getOrThrow()[i] == r'\n') {
                newlinePositions.getOrThrow().add((1 + consumed) + i)
            }
        }
    }
    func isEmpty(): Bool {
        bufferUp()
        return bufPos >= bufLength
    }
    func isEmptyNoBufferUp(): Bool {
        return bufPos >= bufLength
    }
    func current(): Rune {
        bufferUp()
        return if (isEmptyNoBufferUp()) {
            CharacterReader.EOF()
        } else {
            charBuf.getOrThrow()[bufPos]
        }
    }
    func consume(): Rune {
        bufferUp()
        let value = if (isEmptyNoBufferUp()) {
            CharacterReader.EOF()
        } else {
            charBuf.getOrThrow()[bufPos]
        }
        bufPos += 1
        return value
    }
    func unconsume() {
        if (bufPos < 1) {
            throw UncheckedIOException(IOException("WTF: No buffer left to unconsume."))
        }
        bufPos -= 1
    }
    func advance() {
        bufPos += 1
    }
    func nextIndexOf(c: Rune): Int64 {
        bufferUp()
        for (i in bufPos..bufLength) {
            if (c == charBuf.getOrThrow()[i]) {
                return i - bufPos
            }
        }
        return -1
    }
    func nextIndexOf(seq: String): Int64 {
        bufferUp()
        let startChar = seq.toRuneArray()[0]
        var offset = bufPos
        while (offset < bufLength) {
            if (startChar != charBuf.getOrThrow()[offset]) {
                while ((offset += 1 < bufLength) && (startChar != charBuf.getOrThrow()[offset])) {}
            }
            var i = offset + 1
            let last = (i + seq.toRuneArray().size) - 1
            if ((offset < bufLength) && (last <= bufLength)) {
                var j = 1
                while ((i < last) && (seq.toRuneArray()[j] == charBuf.getOrThrow()[i])) {
                    i += 1
                    j += 1
                }
                if (i == last) {
                    return offset - bufPos
                }
            }
            offset += 1
        }
        return -1
    }
    func consumeTo(c: Rune): String {
        let offset = nextIndexOf(c)
        return if (offset != -1) {
            let consumed = cacheString(charBuf, stringCache, bufPos, offset)
            bufPos += offset
            consumed
        } else {
            consumeToEnd()
        }
    }
    func consumeTo(seq: String): String {
        let offset = nextIndexOf(seq)
        return if (offset != -1) {
            let consumed = cacheString(charBuf, stringCache, bufPos, offset)
            bufPos += offset
            consumed
        } else if ((bufLength - bufPos) < seq.toRuneArray().size) {
            consumeToEnd()
        } else {
            let endPos = (bufLength - seq.toRuneArray().size) + 1
            let consumed = cacheString(charBuf, stringCache, bufPos, endPos - bufPos)
            bufPos = endPos
            consumed
        }
    }
    func consumeMatching(`func`: (Rune) -> Bool): String {
        return consumeMatching(`func`, -1)
    }
    func consumeMatching(`func`: (Rune) -> Bool, maxLength: Int64): String {
        bufferUp()
        var pos = bufPos
        let start = pos
        let remaining = bufLength
        let valBuf = charBuf
        while (((pos < remaining) && ((maxLength == -1) || ((pos - start) < maxLength))) && `func`(valBuf.getOrThrow()[pos])) {
            pos += 1
        }
        bufPos = pos
        return if (pos > start) {
            cacheString(charBuf, stringCache, start, pos - start)
        } else {
            ""
        }
    }
    func consumeToAny(chars: Array<Rune>): String {
        return consumeMatching({ c => !chars.iterator().any({ seek => c == seek }) })
    }
    func consumeToAnySorted(chars: Array<Rune>): String {
        return consumeMatching({ c: Rune => chars.binarySearch(c) < 0 })
    }
    func consumeData(): String {
        return consumeMatching({ c => ((c != r'&') && (c != r'<')) && (c != TokeniserState.nullChar) })
    }
    func consumeAttributeQuoted(single: Bool): String {
        return consumeMatching({ c: Rune =>
            ((c != TokeniserState.nullChar) && (c != r'&')) && if (single) {
                c != r'\''
            } else {
                c != r'"'
            }
        })
    }
    func consumeRawData(): String {
        return consumeMatching({ c: Rune => (c != r'<') && (c != TokeniserState.nullChar) })
    }
    func consumeTagName(): String {
        return consumeMatching({ c: Rune =>
            match (c) {
                case r'\t' | r'\n' | r'\r' | r'\u{000c}' | r' ' | r'/' | r'>' => return false
                case _ => ()}
            true
        })
    }
    func consumeToEnd(): String {
        bufferUp()
        let data = cacheString(charBuf, stringCache, bufPos, bufLength - bufPos)
        bufPos = bufLength
        return data
    }
    func consumeLetterSequence(): String {
        return consumeMatching({ ch: Rune => ch.isAsciiLetter() })
    }
    func consumeLetterThenDigitSequence(): String {
        bufferUp()
        let start = bufPos
        while (bufPos < bufLength) {
            if (isAsciiLetter(charBuf.getOrThrow()[bufPos])) {
                bufPos += 1
            } else {
                break
            }
        }
        while (!isEmptyNoBufferUp()) {
            if (StringUtil.isAsciiNumber(charBuf.getOrThrow()[bufPos])) {
                bufPos += 1
            } else {
                break
            }
        }
        return cacheString(charBuf, stringCache, start, bufPos - start)
    }
    func consumeHexSequence(): String {
        return consumeMatching({ c: Rune => isHexDigit(c) })
    }
    func consumeDigitSequence(): String {
        return consumeMatching({ c: Rune => (c >= r'0') && (c <= r'9') })
    }
    func matches(c: Rune): Bool {
        return !isEmpty() && (charBuf.getOrThrow()[bufPos] == c)
    }
    func matches(seq: String): Bool {
        bufferUp()
        let scanLength = seq.toRuneArray().size
        if (scanLength > (bufLength - bufPos)) {
            return false
        }
        for (offset in 0..scanLength) {
            if (seq.toRuneArray()[offset] != charBuf.getOrThrow()[bufPos + offset]) {
                return false
            }
        }
        return true
    }
    func matchesIgnoreCase(seq: String): Bool {
        bufferUp()
        let scanLength = seq.toRuneArray().size
        if (scanLength > (bufLength - bufPos)) {
            return false
        }
        for (offset in 0..scanLength) {
            var scan = seq.toRuneArray()[offset]
            var target = charBuf.getOrThrow()[bufPos + offset]
            if (scan == target) {
                continue
            }
            scan = scan.uppercaseChar()
            target = target.uppercaseChar()
            if (scan != target) {
                return false
            }
        }
        return true
    }
    func matchesAny(seq: Array<Rune>): Bool {
        if (isEmpty()) {
            return false
        }
        bufferUp()
        let c = charBuf.getOrThrow()[bufPos]
        for (seek in seq) {
            if (seek == c) {
                return true
            }
        }
        return false
    }
    func matchesAnySorted(seq: Array<Rune>): Bool {
        bufferUp()
        return !isEmpty() && seq.contains(charBuf.getOrThrow()[bufPos])
    }
    func matchesAsciiAlpha(): Bool {
        if (isEmpty()) {
            return false
        }
        return isAsciiLetter(charBuf.getOrThrow()[bufPos])
    }
    func matchesDigit(): Bool {
        if (isEmpty()) {
            return false
        }
        return StringUtil.isAsciiNumber(charBuf.getOrThrow()[bufPos])
    }
    func matchConsume(seq: String): Bool {
        bufferUp()
        return if (matches(seq)) {
            bufPos += seq.toRuneArray().size
            true
        } else {
            false
        }
    }
    func matchConsumeIgnoreCase(seq: String): Bool {
        return if (matchesIgnoreCase(seq)) {
            bufPos += seq.toRuneArray().size
            true
        } else {
            false
        }
    }
    var lastIcSeq: ?String = None
    var lastIcIndex = 0
    func containsIgnoreCase(seq: String): Bool {
        if (seq == lastIcSeq) {
            if (lastIcIndex == -1) {
                return false
            }
            if (lastIcIndex >= bufPos) {
                return true
            }
        }
        lastIcSeq = seq
        let loScan = seq.toAsciiLower()
        let lo = nextIndexOf(loScan)
        if (lo > -1) {
            lastIcIndex = bufPos + lo
            return true
        }
        let hiScan = seq.toAsciiUpper()
        let hi = nextIndexOf(hiScan)
        let found = hi > -1
        lastIcIndex = if (found) {
            bufPos + hi
        } else {
            -1
        }
        return found
    }
    public override func toString(): String {
        if ((bufLength - bufPos) < 0) {
            return ""
        }
        return charBuf.getOrThrow().concatToString(bufPos, bufPos + (bufLength - bufPos))
    }
    func rangeEquals(start: Int64, count: Int64, cached: String): Bool {
        return rangeEquals(charBuf, start, count, cached)
    }
    static func EOF(): Rune {
        return Rune(UInt32(-1))
    }
    static let MaxStringCacheLen = 12
    static let StringCacheSize = 512
    static func StringPool(): SoftPool<Array<?String>> {
        return SoftPool({ => arrayOfNulls(CharacterReader.StringCacheSize) })
    }
    static func BufferPool(): SoftPool<Array<Rune>> {
        return SoftPool({ => Array<Rune>(CharacterReader.BufferSize(), { _ => r'\u{0000}' }) })
    }
    static func BufferSize(): Int64 {
        return 1024 * 2
    }
    static func RefillPoint(): Int64 {
        return CharacterReader.BufferSize() / 2
    }
    static let RewindLimit = 1024
    static func cacheString(charBuf: ?Array<Rune>, stringCache: ?Array<?String>, start: Int64, count: Int64): String {
        if (count > CharacterReader.MaxStringCacheLen) {
            return String.buildString(charBuf.getOrThrow(), start, count)
        }
        if (count < 1) {
            return ""
        }
        var hash = 0
        let end = count + start
        for (i in start..end) {
            hash = (31 * hash) + Int64(UInt32(charBuf.getOrThrow().toRuneArray()[i]))
        }
        let index = hash & (CharacterReader.StringCacheSize - 1)
        var cached = stringCache.getOrThrow()[index]
        if ((cached.isSome()) && rangeEquals(charBuf, start, count, cached)) {
            return cached
        } else {
            cached = String.buildString(charBuf.getOrThrow(), start, count)
            stringCache[index] = cached
        }
        return cached
    }
    static func rangeEquals(charBuf: ?Array<Rune>, start: Int64, count: Int64, cached: String): Bool {
        var loopCount = count
        if (loopCount == cached.toRuneArray().size) {
            var i = start
            var j = 0
            while (loopCount -= 1 != 0) {
                if (charBuf.getOrThrow()[i += 1] != cached.toRuneArray()[j += 1]) {
                    return false
                }
            }
            return true
        }
        return false
    }
}

extend Array<Rune> {
    func binarySearch(c: Rune): Int64 {
        return this.indexOf(c)
    }
}

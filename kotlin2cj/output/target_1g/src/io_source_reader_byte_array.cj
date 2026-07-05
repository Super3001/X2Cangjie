package target_1g

import std.convert.*

class SourceReaderByteArray <: SourceReader {
    init(bytes: ByteArray) {
        this.source = bytes
    }
    var source: ByteArray
    var currentPosition: Int64 = 0
    var markedPosition: ?Int64 = None
    var isClosed: Bool = false
    public override func mark(readLimit: Int64) {
        markedPosition = currentPosition
    }
    public override func reset() {
        isClosed = false
        if (let Some(it) <- markedPosition) {
            currentPosition = it
            markedPosition = None
        }
    }
    public override func readInt(): Int64 {
        return if (!exhausted()) {
            Int64.parse(source[currentPosition += 1]) & 0xff
        } else {
            -1
        }
    }
    public override func readBytes(count: Int64): ByteArray {
        let byteArray = ByteArray(count)
        var i = 0
        while (!(exhausted()) && (i < count)) {
            byteArray[i] = source[currentPosition += 1]
            i += 1
        }
        return if (i == 0) {
            byteArrayOf()
        } else if (i != count) {
            byteArray.copyOfRange(0, i)
        } else {
            byteArray
        }
    }
    public override func read(bytes: ByteArray, offset: Int64, length: Int64): Int64 {
        var i = offset
        var pos = currentPosition
        while (!(exhausted()) && (i < length)) {
            bytes[i] = source[currentPosition += 1]
            i += 1
        }
        let totalRead = currentPosition - pos
        return if ((totalRead == 0) && exhausted()) {
            -1
        } else {
            totalRead
        }
    }
    public override func readAllBytes(): ByteArray {
        return readBytes(source.size - currentPosition)
    }
    public override func exhausted(): Bool {
        return currentPosition >= source.size
    }
    public override func close() {
        isClosed = true
    }
}

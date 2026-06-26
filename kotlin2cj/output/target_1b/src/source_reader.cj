package target_1b

interface SourceReader {
    func mark(readLimit: Int64): Unit
    func reset(): Unit
    func readInt(): Int64
    func readBytes(count: Int64): Array<Byte>
    func read(bytes: Array<Byte>, offset: Int64, length: Int64): Int64
    func readAllBytes(): Array<Byte>
    func exhausted(): Bool
    func close(): Unit
}

package ksoup_cj

interface SourceReader {
    func mark(readLimit: Int64): Unit
    func reset(): Unit
    func readInt(): Int64
    func readBytes(count: Int64): ByteArray
    func read(bytes: ByteArray, offset: Int64, length: Int64): Int64
    func readAllBytes(): ByteArray
    func exhausted(): Bool
    func close(): Unit
}

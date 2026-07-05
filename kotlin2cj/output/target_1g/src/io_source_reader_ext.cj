package target_1g

extend SourceReader.Companion {
    func from(byteArray: ByteArray): SourceReader {
        return SourceReaderByteArray(byteArray)
    }
}

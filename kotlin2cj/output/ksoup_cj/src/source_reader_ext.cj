package ksoup_cj

extend SourceReader.Companion {
    func from(byteArray: ByteArray): SourceReader {
        return SourceReaderByteArray(byteArray)
    }
}

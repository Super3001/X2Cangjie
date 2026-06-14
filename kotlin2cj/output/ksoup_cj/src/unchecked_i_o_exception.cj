package ksoup_cj

class UncheckedIOException <: Exception {
    init(cause: IOException) {
        super(cause)
    }
    init(message: String) {
        super(IOException(message))
    }
    func ioException(): ?Throwable {
        return cause
    }
}

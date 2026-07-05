package target_1g

class UncheckedIOException <: Exception {
    var cause: ?Exception = None
    init(cause: IOException) {
        super(cause.toString())
            this.cause = cause
    }
    init(message: String) {
        super(IOException(message).toString())
    }
    func ioException(): ?Exception {
        return cause
    }
}

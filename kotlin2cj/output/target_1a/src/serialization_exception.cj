package ksoup_cj

class SerializationException <: RuntimeException {
    init() {
        super()
    }
    init(message: ?String) {
        super(message)
    }
    init(cause: ?Throwable) {
        super(cause)
    }
    init(message: ?String, cause: ?Throwable) {
        super(message, cause)
    }
}

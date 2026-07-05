package target_1g

class SerializationException <: RuntimeException {
    var cause: ?Exception = None
    init() {
        super()
    }
    init(message: ?String) {
        super(message)
    }
    init(cause: ?Exception) {
        super(cause)
            this.cause = cause
    }
    init(message: ?String, cause: ?Exception) {
        super(message, cause)
            this.cause = cause
    }
}

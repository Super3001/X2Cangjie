package target_1g

class IllegalCharsetNameException <: Exception {
    var cause: ?Exception = None
    init() {
    }
    init(message: ?String) {
    }
    init(message: ?String, cause: ?Exception) {
    }
    init(cause: ?Exception) {
    }
}

package target_1g

class PatternSyntaxException <: Exception {
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

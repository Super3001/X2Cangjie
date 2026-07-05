package target_1g

class Validate {
    private init() {}
    public static let INSTANCE = Validate()
    static func expectNotNull<T>(obj: ?T, msg!: ?String = None): T {
        if (let Some(objValue) <- obj) {
            let obj = objValue
            return obj
        } else {
            throw ValidationException(msg ?? "Object must not be null")
        }
    }
    static func isTrue(value: Bool) {
        if (!value) {
            throw ValidationException("Must be true")
        }
    }
    static func isTrue(value: Bool, msg: ?String) {
        if (!value) {
            throw ValidationException(msg)
        }
    }
    static func isFalse(value: Bool) {
        if (value) {
            throw ValidationException("Must be false")
        }
    }
    static func isFalse(value: Bool, msg: ?String) {
        if (value) {
            throw ValidationException(msg)
        }
    }
    static func notEmpty(string: ?String) {
        if (string.getOrThrow().isNullOrEmpty()) {
            throw ValidationException("String must not be empty")
        }
    }
    static func notEmptyParam(string: ?String, param: ?String) {
        if (string.getOrThrow().isNullOrEmpty()) {
            throw ValidationException("The '${param}' parameter must not be empty.")
        }
    }
    static func notEmpty(string: ?String, msg: ?String) {
        if (string.getOrThrow().isNullOrEmpty()) {
            throw ValidationException(msg)
        }
    }
    static func wtf(msg: ?String) {
        throw IllegalStateException(msg)
    }
    static func fail(msg: ?String) {
        throw ValidationException(msg)
    }
    static func assertFail(msg: ?String): Bool {
        fail(msg)
        return false
    }
}

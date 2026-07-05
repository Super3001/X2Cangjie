package target_1g

class AtomicBoolean {
    var value: Bool
    init(value: Bool) {
        this.value = value
    }
    func set(value: Bool) {
        this.value = value
    }
    func get(): Bool {
        return value
    }
}

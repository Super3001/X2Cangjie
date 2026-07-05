package target_1g

class ThreadLocal<T> {
    let defaultValue: () -> T
    init(defaultValue: () -> T) {
        this.defaultValue = defaultValue
    }
    let threadLocalRef = ThreadLocalRef<T>()
    func get(): T {
        return threadLocalRef.get() ?? { it =>
            let _also_it = defaultValue()
            let it = _also_it
            threadLocalRef.value = it
            return _also_it
        }()
    }
    func setValue(value: T) {
        threadLocalRef.value = value
    }
}

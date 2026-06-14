package ksoup_cj

class SoftPool<T> {
    let initializer: () -> T
    init(initializer: () -> T) {
        this.initializer = initializer
    }
    let threadLocalStack: ThreadLocal<ArrayDeque<T>> = ThreadLocal({ => ArrayDeque() })
    func borrow(): T {
        let stack: ArrayDeque<T> = stack
        if (!stack.isEmpty()) {
            return stack.remove(at: 0)
        }
        return initializer()
    }
    func release(value: T) {
        let stack: ArrayDeque<T> = stack
        if (stack.size < SoftPool.MaxIdle) {
            stack.addFirst(value)
        }
    }
    let stack: ArrayDeque<T>
    static let MaxIdle: Int64 = 12
}

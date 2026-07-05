package target_1g

interface Consumer<T> {
    func accept(t: T): Unit
    func andThen(after: Consumer<T>): ?Consumer<T>
}

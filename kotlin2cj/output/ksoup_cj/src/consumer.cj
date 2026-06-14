package ksoup_cj

interface Consumer<T> {
    func accept(t: T): Unit
    func andThen(after: Consumer<T>): ?Consumer<T>
}

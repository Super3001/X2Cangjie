package target_1g

class NodesIterator<T> <: MutableIterator {
    let iterator: MutableIterator<T>
    init(iterator: MutableIterator<T>) {
        this.iterator = iterator
    }
    var currentEntry: ?T = None
    public override func next(): T {
        currentEntry = iterator.next()
        return currentEntry.getOrThrow()
    }
    public override func remove() {
        iterator.remove()
        if ((currentEntry is Node)) {
            (if (currentEntry is Node) { currentEntry as Node } else { None })?.remove()
        }
    }
}

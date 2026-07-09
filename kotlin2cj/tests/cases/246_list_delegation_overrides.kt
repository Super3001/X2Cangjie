open class Registry<T>(private val store: MutableList<T> = mutableListOf()) : MutableList<T> by store {
    override fun first(): T? {
        if (store.isEmpty()) {
            return null
        }
        return store[0]
    }

    override fun last(): T? {
        if (store.isEmpty()) {
            return null
        }
        return store[store.size - 1]
    }

    override fun removeIf(predicate: (T) -> Boolean): Boolean {
        val before = store.size
        val keep = ArrayList<T>()
        for (x in store) {
            if (!predicate(x)) {
                keep.add(x)
            }
        }
        store.clear()
        store.addAll(keep)
        return store.size != before
    }

    fun labels(): Int {
        return store.size
    }
}

fun main() {
    val r = Registry<Int>()
    r.add(1)
    r.add(2)
    r.add(3)
    r.add(4)
    println(r.size)
    println(r.first())
    println(r.last())
    r.removeIf { it % 2 == 0 }
    println(r.size)
    println(r.first())
    println(r.last())
    println(r.labels())
}

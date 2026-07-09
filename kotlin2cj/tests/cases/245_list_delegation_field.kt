open class Bag<T>(private val backing: MutableList<T> = mutableListOf()) : MutableList<T> by backing {
    override fun iterator(): Iterator<T> {
        return backing.iterator()
    }

    fun count(): Int {
        var n = 0
        for (x in this) {
            n += 1
        }
        return n
    }
}

fun main() {
    val b = Bag<Int>()
    b.add(10)
    b.add(20)
    b.add(30)
    println(b.size)
    println(b.count())
    println(b[1])
    b.clear()
    println(b.isEmpty())
}

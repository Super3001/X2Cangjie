class IntBag : MutableList<Int> {
    private val backing = ArrayList<Int>()

    override fun add(element: Int): Boolean {
        backing.add(element)
        return true
    }

    override fun isEmpty(): Boolean {
        return backing.isEmpty()
    }

    fun total(): Int {
        var s = 0
        for (x in backing) {
            s += x
        }
        return s
    }
}

fun main() {
    val b = IntBag()
    b.add(3)
    b.add(4)
    println(b.total())
    println(b.isEmpty())
}

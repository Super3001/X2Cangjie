class MyList : MutableList<String> by mutableListOf() {
    fun total(): Int {
        var s = 0
        for (x in this) {
            s += x.length
        }
        return s
    }
}

fun main() {
    val m = MyList()
    m.add("ab")
    m.add("cde")
    println(m.size)
    println(m.total())
    println(m.isEmpty())
    for (x in m) {
        println(x)
    }
}

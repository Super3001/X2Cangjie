class Store {
    var keys: Int = 2
    var values: Int = 5
}

fun main() {
    val s = Store()
    s.keys = s.keys + 1
    s.values = 9
    println(s.keys)
    println(s.values)
    val m = HashMap<String, Int>()
    m["a"] = 1
    for (k in m.keys) {
        println(k)
    }
}

fun main() {
    val result = ArrayList<Int>()
    val iter = CountIterator(5)
    while (iter.hasNext()) {
        result.add(iter.next())
    }
    println(result.joinToString(" "))
}

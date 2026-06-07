fun main() {
    val builder = StringBuilder()
    for (it in "ab") {
        builder.append(it)
    }
    builder.append('c')
    println(builder.toString())
}

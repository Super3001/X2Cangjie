fun apply(operator: (Int) -> Int, static: Int): Int {
    return operator(static)
}

fun main() {
    val redef = 4
    println(apply({ x -> x * 3 }, redef))
}

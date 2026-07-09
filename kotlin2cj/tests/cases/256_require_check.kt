fun validate(n: Int): Int {
    require(n > 0) { "must be positive, got $n" }
    require(n < 100)
    check(n != 50) { "cannot be fifty" }
    return n
}

fun classify(n: Int): String {
    if (n < 0) {
        error("negative not allowed: $n")
    }
    return "ok"
}

fun main() {
    println(validate(5))
    println(classify(3))
    try {
        validate(-1)
        println("unreachable")
    } catch (e: IllegalArgumentException) {
        println("IAE: ${e.message}")
    }
    try {
        validate(200)
        println("unreachable")
    } catch (e: IllegalArgumentException) {
        println("IAE: ${e.message}")
    }
    try {
        check(false) { "state broken" }
        println("unreachable")
    } catch (e: IllegalStateException) {
        println("ISE: ${e.message}")
    }
    try {
        classify(-5)
        println("unreachable")
    } catch (e: IllegalStateException) {
        println("ISE: ${e.message}")
    }
}

fun join(sep: String = ",", a: String, b: String): String {
    return a + sep + b
}

fun tail(a: String, suffix: String = "!"): String {
    return a + suffix
}

fun main() {
    println(join("-", "x", "y"))
    println(tail("hi"))
    println(tail("hi", "?"))
}

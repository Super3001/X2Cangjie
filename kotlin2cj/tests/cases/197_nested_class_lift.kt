class Outer {
    fun make(): Inner {
        return Inner("ok")
    }

    private class Inner(val value: String) {
        fun text(): String {
            return value
        }
    }
}

fun main() {
    val outer = Outer()
    println(outer.make().text())
}

// Regression (2a R4): anonymous object expression `object : Iface {...}` — Cangjie has
// no anonymous objects; it rendered as a bare `object` keyword (parse error) and left the
// host field typeless. Fix: emit a throw-stub expression and type the field from the
// object's first supertype. Construction throws the stub (caught here) — parses+compiles.
interface Handler {
    fun handle(): Int
}

class Registry {
    val handler: Handler = object : Handler {
        override fun handle(): Int {
            return 42
        }
    }
}

fun probe(): String {
    return try {
        val r = Registry()
        "created"
    } catch (e: Exception) {
        "anon-stub"
    }
}

fun main() {
    println(probe())
}

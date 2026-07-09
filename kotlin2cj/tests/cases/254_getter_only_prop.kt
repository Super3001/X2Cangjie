// Regression (2a R4): getter-only property `val x get() = expr` (no backing field, no
// initializer). skip_property_accessors dropped the getter, leaving a typeless initless
// `let x` (parse error). Fix: capture the getter's `= expr` as the field initializer.
class Config {
    val defaultName get() = "anon"
    val port: Int get() = 8080
    fun describe(): String {
        return "$defaultName:$port"
    }
}

fun main() {
    val c = Config()
    println(c.describe())
    println(c.defaultName)
}

// Regression (2a R3, cluster C root cause): Kotlin multiplatform `expect class`
// with a SEPARATED primary constructor — `expect class Widget` on one line, then
// `public constructor(...) { ...members... }` on the next (KDoc/newlines between).
// parse_class's `skip_modifiers` before the primary ctor did not skip newlines, so
// it failed to consume `public constructor(...)`, produced an empty `class Widget {}`,
// and leaked the whole body (val→uninit top-level `let`, fun→top-level `override`)
// to top level. Fix: skip newlines+modifiers with lookahead for `constructor`/`(`.
// expect-class members render as compilable stubs (fields→throwing props,
// methods/ctors→throw stub) — construction of primary ctor succeeds, member access throws.
public expect class Widget
public constructor(id: Int) {
    public val id: Int
    public val label: String

    public constructor(id: Int, label: String)

    public companion object {
        public fun create(id: Int): Widget?
    }

    public fun render(): String
}

fun probeProp(): String {
    val w = Widget(1)
    return try {
        val n = w.id
        "id=$n"
    } catch (e: Exception) {
        "prop-stub"
    }
}

fun probeMethod(): String {
    val w = Widget(2)
    return try {
        w.render()
    } catch (e: Exception) {
        "method-stub"
    }
}

fun main() {
    println(probeProp())
    println(probeMethod())
}

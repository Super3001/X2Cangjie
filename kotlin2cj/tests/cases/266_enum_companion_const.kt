// Regression (1g R17, cluster A stage②): a Kotlin enum with entry bodies AND a
// companion object that exposes a PUBLIC scalar constant, referenced externally as
// `EnumName.CONST` — the exact shape of ksoup's TokeniserState.nullChar (referenced
// from CharacterReader/Token as `TokeniserState.nullChar`, ×7 "not a member of enum").
//
// Cangjie enums cannot carry static/companion members (probed: `unexpected variable
// declaration in enum body`). So the fix LIFTS each public scalar companion const to a
// same-file top-level `let EnumName__const`, and REWRITES every external `EnumName.const`
// reference to that lifted name. Private consts and companion helper FUNCTIONS are NOT
// lifted this round (their bodies may use constructs the parser doesn't yet handle — e.g.
// `when (val c: Char = ...)`; parsing them would abort the whole file). The parser skips
// those function bodies with a balanced-brace skip, so the enum still translates.
//
// This test pins: (a) entry bodies don't break entry capture; (b) a public companion
// scalar const is reachable via `Signal.MARKER` from outside the enum; (c) a companion
// helper function with a non-trivial body does not abort translation.
enum class Signal {
    First {
        override fun code(): Int = 1
    },
    Second {
        override fun code(): Int = 2
    },
    ;

    abstract fun code(): Int

    companion object {
        // Public scalar const — must lift to top-level and be reachable as Signal.MARKER.
        const val MARKER: Int = 42
        // Private const — not externally visible, not lifted.
        private const val secret: Int = 7

        // Helper with a body that exercises a typed `when` subject (parser must SKIP this
        // body, not parse it, or the whole enum file would fail to translate).
        fun classify(x: Int): String {
            return when (val v: Int = x % 2) {
                0 -> "even"
                else -> "odd"
            }
        }
    }
}

// External reference to the companion constant (this is what broke: Signal.MARKER).
fun useMarker(): Int {
    return Signal.MARKER + 1
}

fun main() {
    println(Signal.First.toString())   // First
    println(Signal.Second.toString())  // Second
    println(Signal.MARKER)             // 42  (lifted companion const, external ref)
    println(useMarker())               // 43
}

// Regression (1g R16, cluster A): Kotlin enum whose entries carry an anonymous class
// body (each entry overrides an abstract method), followed by a `;` separator, the
// abstract method, a nested `object`, and a `companion object` — the exact shape of
// ksoup's TokeniserState (68 entries) and HtmlTreeBuilderState (24 entries).
//
// Before the fix TWO parser bugs bit:
//   1. The entry loop, after reading an entry name, expected `(args)` or `,`. An entry
//      body `{ ... }` matched neither, so the loop broke after the FIRST entry — the
//      other 60+ entries vanished, and every reference to them became
//      "not a member of enum". (Only `First` survived in the emitted .cj.)
//   2. Once entries parsed, the member region after `;` walked token-by-token; a nested
//      `object Constants { ... }` was entered and the loop exited at ITS closing `}`,
//      mistaking it for the enum's — leaking `companion` to the top level
//      ("expected declaration, found 'companion'"), a fatal parse error.
//
// Fix (parser.rs): (a) after an entry name, skip a balanced `{...}` body and keep the
// name; (b) in the post-`;` member region, balance-skip any `{...}` block so nested
// objects/functions don't terminate the enum early.
//
// Stage ② (per-entry method bodies -> enum member func with match(this) dispatch) is a
// separate R17 candidate; this test pins only that ALL entry names survive and the
// companion/nested-object no longer leak — i.e. the enum compiles and every entry is
// referenceable.
enum class Signal {
    First {
        override fun code(): Int = 1
    },
    Second {
        override fun code(): Int = 2
    },
    Third {
        override fun code(): Int = 3
    },
    Last {
        override fun code(): Int = 4
    },
    ;

    abstract fun code(): Int

    // Nested object between the abstract method and the companion — this is what leaked.
    object Constants {
        val tags: Array<String> = arrayOf("a", "b", "c")
    }

    companion object {
        const val sentinel: Int = -1
        fun describe(): String = "signals"
    }
}

fun main() {
    // All four entries must exist and be referenceable (bug #1 dropped everything but First).
    val a = Signal.First
    val b = Signal.Third
    val c = Signal.Last
    println(a.toString())   // First
    println(b.toString())   // Third
    println(c.toString())   // Last
    println(a == Signal.First)   // true
    println(b == Signal.Last)    // false
}

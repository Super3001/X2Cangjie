// Regression (1g R18, cluster A): a Kotlin `enum class` nested inside an `interface`
// — the exact shape of ksoup's NodeFilter.FilterResult (5 entries CONTINUE/SKIP_.../STOP,
// referenced across NodeTraversor as `FilterResult.CONTINUE` etc., ×16 undeclared).
//
// Cangjie interface bodies hold only method signatures — no nested type declarations.
// render_interface previously walked ONLY Kind::Func members and SILENTLY DROPPED the
// nested enum, so FilterResult existed nowhere: neither in the interface nor at top level
// → every `FilterResult.X` reference was "undeclared identifier" and every `FilterResult`
// type annotation was "undeclared type name".
//
// Fix (render.rs render_interface): lift a nested Kind::Enum member to a top-level
// `enum` (emitted after the interface). Reference sites are already bare `FilterResult.X`
// (the enclosing-type qualifier is flattened by render_member), so lifting alone resolves
// them — no requalification needed. Scope this round is enum-in-interface ONLY; nested
// CLASS-in-interface is deferred (it can expose lower-quality translations, e.g. 2a's
// abstract Directive hierarchy) and is an R19 candidate.
interface Walker {
    // Nested enum inside the interface (must be lifted to top level).
    enum class Decision {
        GO,
        SKIP,
        HALT,
    }

    // Interface method whose return type IS the nested enum (bare `Decision` reference).
    fun step(n: Int): Decision
}

// An implementer + external references to the nested enum's entries and type.
class Counter : Walker {
    override fun step(n: Int): Decision {
        return if (n <= 0) Decision.HALT
        else if (n % 2 == 0) Decision.SKIP
        else Decision.GO
    }
}

fun describe(d: Walker.Decision): String {
    return when (d) {
        Walker.Decision.GO -> "go"
        Walker.Decision.SKIP -> "skip"
        Walker.Decision.HALT -> "halt"
    }
}

fun main() {
    val w = Counter()
    println(describe(w.step(3)))   // go   (odd)
    println(describe(w.step(4)))   // skip (even)
    println(describe(w.step(0)))   // halt (<=0)
    println(w.step(3) == Decision.GO)   // true
}

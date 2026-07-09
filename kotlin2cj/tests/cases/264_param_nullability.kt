// Regression (1g R15, cluster E): Kotlin null-aware extension `T?.isNullOrEmpty()`.
// Before the fix it was left untranslated AND the nullable receiver was over-unwrapped
// to `s.getOrThrow().isNullOrEmpty()` — which (a) is not a Cangjie member and (b) would
// throw on null, erasing the very null branch the extension exists to test. The host
// validator body therefore failed to typecheck, and that poisoned decl cascaded
// "no matching function declaration" onto EVERY call site (44 in ksoup's Validate.notEmpty).
//
// Fix: render `x.isNullOrEmpty()` as `((x?.isEmpty()) ?? true)` for a nullable receiver
// (None short-circuits to true; Some runs .isEmpty()), or `x.isEmpty()` when non-null —
// keeping the receiver un-unwrapped. Works for both CharSequence? and Collection?.
//
// This also pins the intended nullability contract: a Kotlin `String?` param stays `?String`
// and a non-null `String` argument passes straight in via Cangjie's implicit T -> ?T at the
// call boundary (no manual wrapper) — so tightening/mapping here must not break either side.
class Validator {
    // Nullable param must remain nullable; body must compile via null-aware isNullOrEmpty.
    fun notEmpty(s: String?): Boolean {
        if (s.isNullOrEmpty()) return false
        return true
    }
}

fun main() {
    val v = Validator()
    // Non-null arg flows straight into the String? param (no wrapper).
    val key: String = "abc"
    println(v.notEmpty(key))         // true
    println(v.notEmpty(""))           // false
    // Nullable arg: null and empty both -> false; present -> true.
    val nul: String? = null
    val some: String? = "x"
    println(v.notEmpty(nul))          // false
    println(v.notEmpty(some))         // true
    // Collection variant of the same null-aware extension on a nullable list.
    val lst: List<Int>? = null
    val lst2: List<Int>? = listOf(1)
    println(lst.isNullOrEmpty())      // true
    println(lst2.isNullOrEmpty())     // false
}

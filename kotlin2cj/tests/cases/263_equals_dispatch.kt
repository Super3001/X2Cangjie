// Regression (1g R13): == semantic closure — structural equals dispatch.
// A class overriding `equals(other: Any?)` must, at call sites `a == b`, dispatch to
// STRUCTURAL equality (not reference). R8 strips equals->hashCode override keyword but the
// body survives; R13 makes the body compile+run (nullable-aware is/as + `::class` reflection)
// and routes `==`/`!=` (both sides same equals-class) to null-safe `.equals()` dispatch.
// Classes WITHOUT equals keep reference identity (refEq2 bucket) — must not interfere.

class Point(val x: Int, val y: Int) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other == null || this::class != other::class) return false
        val that = other as Point
        return x == that.x && y == that.y
    }
    override fun hashCode(): Int = x * 31 + y
}

// No equals override -> reference identity semantics.
class Ref(val id: Int)

fun main() {
    // ---- structural equality (same value, distinct instances) ----
    val a = Point(1, 2)
    val b = Point(1, 2)
    val c = Point(3, 4)
    println(a == b)        // true  (structural: 1,2 == 1,2)
    println(a == c)        // false
    println(a != c)        // true
    println(a == a)        // true  (=== short-circuit)
    println(a != b)        // false

    // ---- nullable combos ----
    val na: Point? = Point(1, 2)
    val nb: Point? = Point(1, 2)
    val nn: Point? = null
    println(na == nb)      // true  (both non-null, structural)
    println(na == nn)      // false (one null)
    println(nn == nn)      // true  (both null)
    println(na == a)       // true  (opt vs bare)
    println(a == na)       // true  (bare vs opt)
    println(nn != na)      // true

    // ---- reference-identity class (no equals) must NOT dispatch to structural ----
    val r1 = Ref(5)
    val r2 = Ref(5)        // same id, distinct instance
    val r3 = r1
    println(r1 == r2)      // false (identity: distinct instances)
    println(r1 == r3)      // true  (same instance)
    println(r1 != r2)      // true
}

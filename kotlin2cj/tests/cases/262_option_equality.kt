// Regression (1g R12): ==/!= nullable & reference equality normalization.
// Cangjie reference classes have NO default `==`, and Option<T> vs T mixing is a type
// mismatch. render_eq_normalized buckets by operand category:
//   A (Ref):        node identity → __k2cjRefEq2(a, b) (auto-boxes bare, passes Option,
//                   two type-params resolve cross-subtype). Covers Option<Cls> vs Cls,
//                   Option<Cls> vs Option<Cls>, Cls vs Cls, `this === other`.
//   B (Equatable):  one side Option<value>, other bare → wrap bare in Some(...) so
//                   Option<T> == Option<T> holds.
//   C (has equals): a class defining equals() still routes to bucket A (reference
//                   identity) this round — structural `a.equals(b)` closure is deferred
//                   to R13 (blocked by ?Object auto-box vs when-is/as match gap).
// `x == null`/`x != null` still map to isNone()/isSome() (unchanged).

class Node(val id: Int) {
    var parent: Node? = null
    fun root(): Node {
        var n: Node = this
        while (n.parent != null) {
            n = n.parent!!
        }
        return n
    }
    // `this === other`: reference identity (degrades to == but must stay refEq).
    fun sameRef(other: Node?): Boolean {
        return this === other
    }
}

// Structural equality class (bucket C): equals() defines value equality.
// Plain reference class (no equals) — must stay in the refEq2 identity bucket.
// (Structural equals-dispatch is covered by 263_equals_dispatch.)
class Box(val v: Int)

fun main() {
    // ---- Bucket A: reference identity ----
    val a = Node(1)
    val b = Node(2)
    val c = Node(3)
    a.parent = b            // a's parent is b; root of a is b
    val ra: Node = a.root() // = b
    // Option<Node>(parent) vs Node
    println(a.parent == b)          // true  (same ref)
    println(a.parent == a)          // false
    // Node vs Node (both bare ref)
    println(ra == b)                // true
    println(a != b)                 // true
    // Option<Node> vs Option<Node>: Some(b) vs None -> false
    println(a.parent == c.parent)   // false
    // None == None -> true
    println(b.parent == c.parent)   // true
    // `this === other`
    println(a.sameRef(a))           // true
    println(a.sameRef(b))           // false
    println(a.sameRef(null))        // false

    // ---- Bucket B: Option<value> vs bare value ----
    val name: String = "x"
    val maybe: String? = "x"
    val none: String? = null
    println(maybe == name)          // true  (Some("x") == Some("x"))
    println(none == name)           // false
    println(name != maybe)          // false

    // ---- Bucket C: plain reference class -> refEq2 identity (structural in 263) ----
    val p = Box(5)
    val q = Box(5)
    val p2 = p
    println(p == q)                 // false (distinct refs)
    println(p == p2)                // true  (same ref)
    println(p != q)                 // true

    // ---- null-literal (unchanged isNone/isSome) ----
    println(maybe == null)          // false
    println(none == null)           // true
    println(maybe != null)          // true
}

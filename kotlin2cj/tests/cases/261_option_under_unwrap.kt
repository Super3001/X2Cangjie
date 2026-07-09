// Regression (1g R11): under-unwrap. A nullable receiver `x: ?T` calling a member
// `x.foo()` must unwrap to `x.getOrThrow().foo()` — the method-call path went through
// render_member_call/atom which did NOT auto-unwrap (only field-access via render_member
// did). Two gaps fixed: (1) render_member_call now unwraps its receiver; (2) is_nullable_expr
// now infers a local's nullability from a Call/Member initializer (loop-walk locals like
// `var cur = start()` were seen as non-null). Boundaries preserved: `?.` safe calls stay
// short-circuit (no getOrThrow); if-let smart-cast rebinds stay un-unwrapped (R10).
class Cell(val v: Int) {
    var link: Cell? = null
    fun next(): Cell? = link
    fun tag(): String = "c$v"
}

class Ring {
    var head: Cell? = null
    fun start(): Cell? = head

    // loop-walk: local `cur` inferred nullable from method init; method + field access on
    // the reassigned local must unwrap (cur.next() and cur.v).
    fun sum(): Int {
        var total = 0
        var cur = start()
        while (cur != null) {
            total += cur.v
            cur = cur.next()
        }
        return total
    }

    // && short-circuit guard on a nullable local: 2nd operand `h.tag()` must unwrap
    // (safe because `h != null &&` short-circuits).
    fun headTag(): String {
        val h = start()
        if (h != null && h.tag() == "c1") return "one"
        return "none"
    }

    // if-let rebind (R10 non-regression): inside the guarded block `h` is the non-Option
    // rebind, so `h.tag()` must NOT get getOrThrow.
    fun firstOrNone(): String {
        val h = start()
        if (h != null) {
            return h.tag()
        }
        return "empty"
    }

    // safe-call non-regression: `?.` keeps None short-circuit, no getOrThrow.
    fun safeTag(): String {
        return head?.tag() ?: "nil"
    }
}

fun main() {
    val r = Ring()
    println(r.sum())
    println(r.headTag())
    println(r.firstOrNone())
    println(r.safeTag())
    val a = Cell(1)
    val b = Cell(2)
    a.link = b
    r.head = a
    println(r.sum())
    println(r.headTag())
    println(r.firstOrNone())
    println(r.safeTag())
}

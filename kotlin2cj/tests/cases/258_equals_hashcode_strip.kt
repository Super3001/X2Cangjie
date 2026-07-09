// Regression (2a R6 cluster2): Kotlin Any has equals/hashCode; Cangjie Object does not,
// so `override fun equals/hashCode` -> 'does not have an overridden function in supertype'.
// Fix: strip override on equals/hashCode when no ancestor class / interface defines them
// (keeps the method body as a plain method). Both Tag and Wrapper have no such ancestor,
// so both strip and compile. (Explicit `.equals()` still maps to `==` -- known == gap.)
class Tag(val name: String) {
    override fun equals(other: Any?): Boolean {
        return other != null
    }
    override fun hashCode(): Int {
        return name.length * 7
    }
    fun show(): String {
        return name
    }
}

class Wrapper(val tag: Tag) {
    override fun hashCode(): Int {
        return tag.hashCode() + 1
    }
    fun describe(): String {
        return tag.show()
    }
}

fun main() {
    val t = Tag("hello")
    println(t.show())
    println(t.hashCode())
    val w = Wrapper(t)
    println(w.describe())
    println(w.hashCode())
}

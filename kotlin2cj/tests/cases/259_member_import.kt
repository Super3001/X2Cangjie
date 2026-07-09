// Regression (R9 cluster2): Kotlin static/companion member import `import P.C.member`
// / `import P.C.Companion.CONST` then bare `member`/`CONST` usage. Translator skipped
// imports entirely -> bare ref undeclared. Fix: record member imports (member->C) and
// rewrite unresolved bare NameRefs to `C.member`. Local decls (decl=Some) keep priority.
import demo.Config.Companion.MAX
import demo.Text.upper

object Text {
    fun upper(s: String): String {
        return "U:$s"
    }
}

class Config {
    companion object {
        val MAX: Int = 42
    }
}

fun greet(name: String): String {
    return upper(name)
}

fun main() {
    println(greet("hi"))
    println(MAX)
}

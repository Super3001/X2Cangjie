// Regression (1g R19, cluster not-member-of-class): a MULTI-LEVEL nested type
// qualifier chain — the exact shape of ksoup's `Document.OutputSettings.Syntax.xml`
// (a nested enum `Syntax` inside a nested class `OutputSettings` inside `Document`,
// referenced cross-file as the fully-qualified 3-level chain, ×7 errors).
//
// render_member's single-level NameRef flatten only collapses `Parent.Nested` when the
// base is a bare NameRef. For `Document.OutputSettings.Syntax`, the middle `Syntax`'s base
// `Document.OutputSettings` is itself a Member node (not a NameRef), so the flatten never
// fired → residual `OutputSettings.Syntax.xml` → "'Syntax' is not a member of class
// 'OutputSettings'". Fix (render.rs type_qualifier_class): when base is a Member that
// resolves as a pure type-qualifier chain and `name` is a nested type of it, collapse to
// the (lifted) bare name — same rule as the single-level case, applied recursively.
class Document {
    class OutputSettings {
        enum class Syntax { html, xml }

        var syntax: Syntax = Syntax.html
    }
}

// External code that references the enum via the full 3-level qualifier.
fun isXml(s: Document.OutputSettings.Syntax): Boolean {
    return s == Document.OutputSettings.Syntax.xml
}

fun main() {
    val os = Document.OutputSettings()
    // Assign via full qualifier chain.
    os.syntax = Document.OutputSettings.Syntax.xml
    println(isXml(os.syntax))                                // true
    println(isXml(Document.OutputSettings.Syntax.html))      // false
    // Bare reference (in-scope form) must still work unchanged.
    val s = Document.OutputSettings.Syntax.html
    println(s == Document.OutputSettings.Syntax.html)        // true
}

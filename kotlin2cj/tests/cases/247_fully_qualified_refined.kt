// Regression: `org.koin.dsl.KoinAppDeclaration` fully-qualified type reference.
// R3 attempted simple "only keep last segment" but broke 221_nested_class_lifting
// (Outer.Inner also uses `.`). This test verifies the refined fix:
// package prefix (all-lowercase idents like `org.koin.dsl`) is stripped,
// nested class (PascalCase idents like `Outer.Inner`) is preserved.

package test.pkg

class Foo {
    override fun toString(): String = "foo"
}

fun describeFoo(f: test.pkg.Foo): String {
    return "${f}"
}

fun main() {
    val f = Foo()
    println(describeFoo(f))
}

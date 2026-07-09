// Regression (2a R3, cluster D): Kotlin multiplatform `expect fun` (no body in
// common; actual lives in an untranslated platform dir) rendered as a bodiless
// function → "body of function is missing". Now rendered as a `throw` stub so
// call sites still resolve. Overloads that collapse to the same Cangjie
// signature (safeMultiply(Long,Long)/(Int,Int) both → (Int64,Int64)) are
// de-duplicated to avoid redefinition. Both stubs throw → caught → *-stub.
internal expect fun safeMultiply(a: Long, b: Long): Long
internal expect fun safeMultiply(a: Int, b: Int): Int
internal expect fun safeAdd(a: Long, b: Long): Long
internal expect fun safeAdd(a: Int, b: Int): Int

fun tryMul(): String {
    return try {
        val r = safeMultiply(3L, 4L)
        "got $r"
    } catch (e: Exception) {
        "mul-stub"
    }
}

fun tryAdd(): String {
    return try {
        val r = safeAdd(1L, 2L)
        "got $r"
    } catch (e: Exception) {
        "add-stub"
    }
}

fun main() {
    println(tryMul())
    println(tryAdd())
}

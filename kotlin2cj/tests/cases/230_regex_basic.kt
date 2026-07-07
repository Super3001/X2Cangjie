// Stub regression: Kotlin `Regex` maps to a thin wrapper over std.regex.
// Verifies matches / replace / toRegex compile and behave correctly.
// (Avoids `find` — collides with Iterable.find heuristic; `first`/`last`
//  fields hit the collection-index render path. Both are separate clusters.)
fun main() {
    val re = Regex("hello")
    println(re.matches("hello"))
    println(re.matches("world"))
    println("hello".toRegex().matches("hello"))
    println(re.containsMatchIn("say hello now"))
    println(re.replace("hello world hello", "bye"))
    println(re.replaceFirst("hello world hello", "bye"))
}

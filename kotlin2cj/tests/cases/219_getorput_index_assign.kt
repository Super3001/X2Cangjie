fun main() {
    val tags = HashMap<String, HashMap<String, Int>>()
    tags.getOrPut("html") { HashMap() }["div"] = 1
    tags.getOrPut("html") { HashMap() }["span"] = 2
    tags.getOrPut("svg") { HashMap() }["rect"] = 3
    println(tags.size)
    println(tags["html"]!!.size)
    println(tags["svg"]!!.size)
    println(tags["html"]!!["div"])
}

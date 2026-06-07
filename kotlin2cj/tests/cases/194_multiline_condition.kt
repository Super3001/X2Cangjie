fun main() {
    var end = 0
    val seqEnd = 3
    while (
        end < seqEnd && (
            end in 0..2
            || end == 10
        )
    ) {
        end++
    }
    println(end)
}

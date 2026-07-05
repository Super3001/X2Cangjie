fun pick(flag: Boolean): String {
    var r = ""
    if (flag)
        r = "yes";
    else
        r = "no";
    return r
}

fun main() {
    println(pick(true))
    println(pick(false))
}

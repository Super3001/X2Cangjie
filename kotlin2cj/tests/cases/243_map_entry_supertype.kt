class Prop : Map.Entry<String, Int> {
    fun describe(): String {
        return "entry"
    }
}

class Reg : MutableMap<String, Int> {
    fun label(): String {
        return "reg"
    }
}

fun main() {
    val p = Prop()
    println(p.describe())
    val r = Reg()
    println(r.label())
}

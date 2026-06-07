fun main() {
    val values = mutableMapOf<String, String>()
    values["x"] = "ok"
    val result = values["x"]
    if (result != null) {
        println(result)
    }
}

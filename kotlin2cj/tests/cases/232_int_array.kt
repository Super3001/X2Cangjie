// Stub regression: `IntArray` is a type alias for `Array<Int64>`.
fun main() {
    val arr: IntArray = IntArray(3) { 0 }
    arr[0] = 10
    arr[1] = 20
    arr[2] = 30
    println(arr.size)
    println(arr[0] + arr[1] + arr[2])
}

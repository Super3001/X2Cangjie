// 顶层 Comment：与 Token.kt 中提升出的嵌套类 Token.Comment 撞名
class Comment(val text: String) {
    fun show(): String {
        return "node:" + text
    }
}

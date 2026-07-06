open class Token {
    // 与顶层 Comment 撞名 → 提升时应重命名为 TokenComment
    class Comment : Token() {
        var data: String = ""
        fun show(): String {
            return "token:" + data
        }
    }

    // 无撞名 → 提升后保持原名 Doctype
    class Doctype : Token() {
        var name: String = ""
    }
}

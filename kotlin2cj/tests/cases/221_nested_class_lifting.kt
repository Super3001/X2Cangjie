// 嵌套类提升：限定名引用改写（类型位 / is 模式 / 构造调用 / 嵌套 enum 常量）
// + 提升撞名消歧（顶层 Tag 与 Token.Tag 撞名 → 嵌套类重命名为 TokenTag）
class Tag(val name: String) {
    fun describe(): String {
        return "top:" + name
    }
}

open class Token {
    var type: TokenType = TokenType.EOF

    enum class TokenType {
        StartTag,
        EndTag,
        EOF
    }

    open class Tag : Token() {
        var tagName: String? = null
        fun name(): String {
            return tagName ?: ""
        }
    }

    class StartTag : Tag()
}

fun process(token: Token): String {
    if (token.type == Token.TokenType.EOF) {
        return "eof"
    }
    if (token is Token.StartTag) {
        return "start"
    }
    return "other"
}

fun main() {
    val top = Tag("div")
    println(top.describe())
    val t: Token.Tag = Token.StartTag()
    t.tagName = "span"
    t.type = Token.TokenType.StartTag
    println(process(t))
    println(t.name())
}

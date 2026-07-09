package recovery

// 本文件的 parseImpl 使用多行函数类型 + 命名参数（kotlinx-datetime
// DateTimePeriod.kt 同款构造），当前解析器无法解析。本用例验证合并翻译的
// 错误恢复：解析失败后应跳到下一个 package 边界继续（错误点位于嵌套
// 花括号内，恢复计数须容忍 depth 变负），不得丢弃后续文件。
class Choker {
    companion object {
        private inline fun <T> parseImpl(
            text: String,
            construct: (
                years: Int, months: Int
            ) -> T
        ): T {
            return construct(1, 2)
        }
    }
}

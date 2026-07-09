// 字符串插值内含会展开成多行块的表达式（嵌套 if / 多语句块）。
// 仓颉单行字符串插值不允许换行；render 层须把插值表达式内的换行折叠为单行，
// 且以 ';' 保留多语句块的语句边界（不能只折成空格，否则相邻语句粘连报错）。
// 注：Kotlin 的 `x?.let{} ?: d` 会渲染成 `if(let Some..){} ?? d`——那是独立的
// 语义层问题（if-let 产 Unit 不可 ??），本用例用等价的 if/else 形式以保证可运行。

fun sign(neg: Boolean?): String {
    // 嵌套 if：翻译器为 smart-cast 插入 `let neg = ...` → 多语句块，折叠须用 ';'
    return "${if (neg != null) { if (neg) "-" else "+" } else " "}end"
}

fun grade(score: Int): String {
    // 首分支为多语句块 `val g = ...; g`，折叠须用 ';' 保留边界
    return "[${if (score >= 90) { val g = "A"; g } else if (score >= 60) { "B" } else { "F" }}]"
}

fun main() {
    println(sign(true))
    println(sign(false))
    println(sign(null))
    println(grade(95))
    println(grade(70))
    println(grade(30))
}

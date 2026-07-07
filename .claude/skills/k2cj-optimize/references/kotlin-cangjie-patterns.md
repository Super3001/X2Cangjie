# Kotlin → Cangjie 翻译模式目录

> 活的参考文档。每次 fixer 发现新模式或 diagnostician 识别出新的 gap 类型，追加到这里。
> diagnostician 和 fixer agent 在分析/修复错误前**必须先读此文件**。

---

## 空安全模式

| Kotlin | Cangjie | L 级 | 说明 |
|--------|---------|------|------|
| `x?.prop` | `x?.prop` | L1 | 直译，仓颉原生支持 |
| `x!!` | `x.getOrThrow()` | L1 | 非空断言 |
| `x?.let { it → ... }` | `if (let Some(it) = x) { ... }` | L2 | 安全作用域重绑定 |
| `x ?: default` | `x ?? default` | L1 | Elvis → 空合并 |
| `if (x != null) { x.foo() }` | `x?.foo()` 或 `if (let Some(v) = x) { v.foo() }` | L1/L2 | smart cast → 显式重绑定 |
| `x.also { it -> body }` | `({ => let _also_it = x; <body with it→_also_it>; return _also_it })()` | L2 | also lambda 内联:body 的 `it` NameRef 重命名为 `_also_it`,避免与外部 lambda 的 `it` 作用域冲突(R4 it-shadowing 修复) |

## 集合模式

| Kotlin | Cangjie | L 级 | 说明 |
|--------|---------|------|------|
| `listOf(a, b)` | `[a, b]` | L1 | |
| `mutableListOf(a, b)` | `ArrayList<X>([a, b])` | L1 | |
| `mapOf(k to v)` | `HashMap<X, Y>([(k, v)])` | L1 | |
| `x.map { ... }` | `x.map { ... }` | L1 | 直译，返回迭代器 |
| `x.map { ... }.toList()` | `x.map { ... }.toList()` 或 `[for (e in x) ...]` | L1 | |
| `x.filter { ... }` | `x.filter { ... }` | L1 | |
| `for (e in x)` | `for (e in x)` | L1 | |
| `x.forEach { ... }` | `for (e in x) { ... }` | L1 | 惯用法：forEach→for |
| `x.indices` | `0..x.size` | L1 | |
| `x[i]` (List) | `x[i]` | L1 | |
| `x[i]` (String) | `x.get(i)` 或 `x.toRuneArray()[i]` | L1 | String 不能用下标取 Rune |
| Kotlin stdlib 类型(Regex/Reader/KClass/Charset 等) | 注入 stub(`k2cj_stubs.cj`) | L2 | stubs.rs 数据驱动表 `StubDef { provides, markers, imports, code }`,project 模式生成独立文件,单文件模式追加到 body 末尾。`defines_type` 守卫避免与用户自定义冲突(R2 stdlib-type-surface 簇修复) |

## 数据类模式

| Kotlin | Cangjie | L 级 | 说明 |
|--------|---------|------|------|
| `data class X(val a: Int)` | `class X { let a: Int64; public init(a: Int64) { this.a = a } }` | L2 | 仓颉无 data class |
| `x.copy(a = 1)` | `X(a: 1, ...)` 或手动构造 | L2 | |
| `x.toString()` | 自动生成（需 `@Derive[ToString]`） | L1 | |
| `x.equals(y)` | `x == y` | L1 | |
| `x.hashCode()` | `x.hash()` | L1 | |

## 密封类/枚举模式

| Kotlin | Cangjie | L 级 | 说明 |
|--------|---------|------|------|
| `sealed class Expr` | `enum Expr { Add(Int64, Int64) | Sub(Int64, Int64) }` | L2 | 仓颉 enum 带 payload |
| `when (x) { is A → ... is B → ... }` | `match (x) { case A → ... case B → ... }` | L1 | |

## 扩展函数/属性模式

| Kotlin | Cangjie | L 级 | 说明 |
|--------|---------|------|------|
| `fun String.foo(): X` | `func foo(s: String): X` 自由函数 | L2 | 仓颉无扩展函数 |
| `val String.prop: X get() = ...` | `func prop(s: String): X` 自由函数 | L2 | 扩展属性→函数 |

## 伴生对象/静态模式

| Kotlin | Cangjie | L 级 | 说明 |
|--------|---------|------|------|
| `companion object { fun foo() }` | `static func foo()` in class | L2 | |
| `X.Companion.foo()` → `X.foo()` | 去掉 `.Companion` | L1 | |
| `object X { ... }` | `class X { static init { ... } }` | L3 | 单例→静态初始化 |

## 协程/异步模式（暂无对应）

| Kotlin | Cangjie | L 级 | 说明 |
|--------|---------|------|------|
| `suspend fun foo()` | 无直接对应 | L3 | 需重构调用链 |
| `launch { ... }` | 无直接对应 | L3 | 需显式线程管理 |

## 类型系统差异

| Kotlin | Cangjie | 注意 |
|--------|---------|------|
| `Int` | `Int64` | 宽度不同，Kotlin Int 是 32-bit |
| `Long` | `Int64` | 宽度相同 |
| `Float` / `Double` | `Float32` / `Float64` | 命名不同 |
| `Char` | `Rune` | 仓颉 Rune = Unicode scalar value |
| `String` | `String` | 相同，但方法名不同（见 stdlib_map.rs） |
| `Unit` | `()` 或省略返回类型 | 仓颉无 Unit 类型 |
| `Nothing` | `Never` | 底部类型 |
| `Any` | `Object` | 顶部类型 |
| `typealias X = Y` | `type X = Y` | 仓颉去掉了 alias |

## 作用域冲突模式（SOC 检测）

> Kotlin 允许参数名/局部变量名/成员名/lambda 参数名相互 shadowing,仓颉不允许。译器需主动检测并重命名。

| Kotlin 模式 | 译器处理 | L 级 | 说明 |
|--------|---------|------|------|
| `class X(var a: T) { fun a() }` (CtorParam var 撞方法名) | SOC `resolve_var_func_collisions` 检测 CtorParam 名是否在 `func_names` 里,冲突则 CtorParam.name 改成 `_X`,全图 NameRef == X 改成 _X(保守名字匹配) | L2 | engine.rs CtorParam 检测分支(R3 redefinition-of-declaration 簇修复,8 个 setter redefinition 消掉) |
| `class X { fun a(a: T) }` (setter 参数名撞成员名) | 同上,SOC 检测后参数名重命名 | L2 | R3 行动簇,7 个 document.cj setter(parser/escapeMode/charset/syntax/prettyPrint/outline/indentAmount) |
| `interface X { fun f(p: T = default) }` (interface 默认参数) | render_interface strip 默认参数后缀 ` = <default>` | L1 | render.rs render_interface 加默认参数 strip(R3 optional-parameter-in-abstract 修复)。**副作用**:调用方失去默认参数支持,Kotlin `r.read(bytes)` 不传 offset/length 仓颉需补值,这是另一个 bug 簇 |
| `lambda { it -> ... lambda { it -> ... } }` (嵌套 lambda 的 it) | also lambda 内联:body 的 `it` NameRef 重命名为 `_also_it`,decl 指向 `_also_it` 声明的 Name 节点 | L2 | parser.rs build_also 重构 + rename_namerefs_in_subtree(R4 it-shadowing 修复,6 个 it redefinition 消掉) |
| `fun f(p: T) { val p = ... }` (参数名/局部变量名 shadowing) | 未修复 — R5 候选 | — | 1g 剩余 3 redefinition(append×2 + attributeKey×1),Kotlin 允许,仓颉不允许 |

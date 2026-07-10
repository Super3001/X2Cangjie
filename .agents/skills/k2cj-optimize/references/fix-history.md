# 修复历史

> diagnostician 和 fixer 每次修复后**必须**追加一条记录。避免重复修复、追踪模式、积累知识。

---

## 记录格式

```markdown
### <日期> — <错误类别> — <简短描述>
- **目标**: <哪个代码库>
- **文件**: <修复了哪个源文件>
- **修改**: <具体改了什么>
- **层级**: L1/L2/L3
- **测试**: <新增测试用例编号>
- **耗时**: <大约分钟>
```

---

## 记录

### 2026-06-14 — RENDER_GAP — Index on String 需 .get() 而非 []
- **目标**: ksoup
- **文件**: `render.rs` — `render_index()`
- **修改**: String 下标 `x[i]` → `x.get(i)` 或 `x.toRuneArray()[i]`
- **层级**: L1
- **测试**: 新增
- **耗时**: ~20min

### 2026-06-14 — HEURISTIC_GAP — looks_string 未覆盖 codePointAt
- **目标**: ksoup
- **文件**: `heuristics.rs` — `looks_string()`
- **修改**: `matches!` 中追加 `"codePointAt"` 等方法名
- **层级**: L1
- **测试**: 新增 214
- **耗时**: ~10min

### 2026-06-14 — PARSER_GAP — ksoup 的 @Override 注解导致解析失败
- **目标**: ksoup
- **文件**: `parser.rs` — 新增 `skip_annotations()`
- **修改**: 在 `parse_program()` 循环中跳过 `@` 开头的注解
- **层级**: L1
- **测试**: 已有测试全量通过，注解本身无语义
- **耗时**: ~30min

### 2026-06-16 — RENDER_GAP — project 翻译路径缺少 __k2cjRuneSlice helper 注入
- **目标**: Phase 0 回归 (proj_extensions, proj_patterns, proj_stringops)
- **文件**: `project.rs` — `convert_project()` 文件拼装段
- **修改**: 在 project 每文件拼装输出前检测 `__k2cjRuneSlice(` 并注入 helper 函数定义，与 `render_program()` 单文件路径对齐
- **层级**: L1
- **测试**: Phase 0 项目测试 30/33 → 33/33
- **耗时**: ~15min

### 2026-06-17 — RENDER_GAP — open func 不能有默认参数值
- **目标**: ksoup-parser (1d)
- **文件**: `render.rs` — `render_func()`
- **修改**: 当函数标记为 `open` 时（`in_open_class` 或 `is_override && in_open_class`），从参数中剥离 ` = <default>` 后缀。仓颉不允许 `open` 函数有默认参数值。
- **层级**: L1
- **测试**: 全量回归 202/202 + 33/33 通过
- **耗时**: ~30min

### 2026-06-17 — RENDER_GAP — 平凡 getter 函数与字段冲突
- **目标**: ksoup-parser (1d)
- **文件**: `render.rs` — `render_regular_class()` 成员循环
- **修改**: 在渲染类成员前检测平凡 getter 函数（无参、非 override、名称与 CtorParam/VarDecl 字段冲突），跳过渲染。字段声明已提供访问。
- **层级**: L1
- **测试**: 全量回归 202/202 + 33/33 通过
- **耗时**: ~20min

### 2026-06-17 — RENDER_GAP — 扩展函数在类内声明不合法
- **目标**: ksoup-parser (1d)
- **文件**: `render.rs` — `render_regular_class()` 成员循环
- **修改**: 检测 `Func` 成员是否有 `receiver_type`（扩展函数），若有则提升到类外的顶层 `lifted` 列表，与嵌套类/枚举统一处理。
- **层级**: L1
- **测试**: 全量回归 202/202 + 33/33 通过
- **耗时**: ~15min

### 2026-06-17 — HEURISTIC_GAP — 构造函数调用类型推断缺失
- **目标**: ksoup-parser (1d)
- **文件**: `heuristics.rs` — `expr_type_name_depth()`, `render.rs` — `render_var_decl_without_init()`
- **修改**: (1) `Call` 的 `NameRef` callee 若为已注册类名 → 返回类名作为类型；(2) `Call` 的 `Member` callee 若 member 名为已注册类名 → 返回类名；(3) 最后手段：从渲染后的 init 文本提取构造器名作为类型。
- **层级**: L2
- **测试**: 全量回归 202/202 + 33/33 通过
- **耗时**: ~25min

### 2026-06-17 — 1d ksoup-parser 状态
- **翻译器修复**: 4 个 RENDER_GAP/HEURISTIC_GAP 修复，全量回归通过
- **剩余问题**: 16 文件翻译成功，但约 30+ 跨包子包类型未定义（Node, Element, Document, Attributes, StringUtil, SoftPool, Reader, NodeVisitor, Evaluator 等）
- **结论**: parser 包跨包依赖过多，单独翻译不可行。需翻译完整 ksoup src（87 文件）或修复全量合并翻译的解析失败（Entities.kt 的 `@file:OptIn` 注解）。建议 1d → 1g 合并，以完整 ksoup 翻译为目标，重点攻克 parser 特性（state machine, when, inline）。

### 2026-06-17 — RENDER_GAP — map_type 非泛型分支缺失多类型映射
- **目标**: ksoup (1g full)
- **文件**: `parser.rs` — `map_type()` 非泛型 match 分支
- **修改**: 添加 `IntArray→Array<Int64>`, `ShortArray→Array<Int64>`, `LongArray→Array<Int64>`, `FloatArray→Array<Float64>`, `DoubleArray→Array<Float64>`, `BooleanArray→Array<Bool>`, `Map.Entry→Entry`, `Map→HashMap`, `List→ArrayList`, `Set→HashSet` 的非泛型映射。泛型分支已有同名映射，非泛型分支遗漏导致无类型参数时映射失败
- **层级**: L1
- **测试**: Phase 0 全量回归 202/202 + 33/33 通过
- **耗时**: ~25min
- **备注**: 修复已提交但无法重新翻译验证（无 ksoup Kotlin 源）。编译输出 1601 errors，8 printed — 顶层错误包含 undeclared inner class refs (inner class promotion 后类型引用未更新)、stdlib API gaps、mismatched types (Option vs T)、lambda/IIFE 问题

### 2026-06-17 — PARSER_GAP — skip_property_accessors 换行误终结，类成员外泄到顶层

- **目标**: 1c okhttp-mockwebserver
- **错误**: mock_web_server_socket.cj — `get() = when { ... }` 多行属性访问器体后，后续成员全部外泄到顶层（handshake/handshakeServerNames/cancel/close/shutdown/awaitClosed 变为 top-level）
- **根因**: `skip_property_accessors` 跳过 `get() =\n when { ... }` 时：(a) `\n` 在 `=` 后立即终止循环；(b) 表达式内的 `}` 未深度跟踪，被类体循环当类闭合 `}` 消费
- **修复**: 引入大括号深度跟踪 `depth`。跳过 `=` 后的开头空白换行。进入主循环后：`{`→depth+1, `}` 若 depth>0→depth-1, 若 depth=0→停止。换行仅当 depth=0 且后续 token 是声明关键字/大括号时停止（避免吃掉下一成员）
- **层级**: L1 (~25 行)
- **测试**: Phase 0 202/202 + 33/33 通过
- **文件**: parser.rs `skip_property_accessors()`
- **备注**: 修复还涉及声明关键字前探 (`DECL_KEYWORDS`)，避免多行表达式吃掉后续成员的 `val`/`fun` 关键字

### 2026-06-17 — RENDER_GAP — companion object main() 无法渲染为顶层函数

- **目标**: 1c okhttp-mockwebserver
- **错误**: http2_server.cj — `companion object { @JvmStatic fun main() }` → `static main()` 在类内，仓颉不允许
- **根因**: render_regular_class 将 companion 成员一律加 `static` 前缀留在类内，未处理 `main()` 需要顶层化的特例
- **修复**: 检测 companion 成员中 `safe_name(func_name).trim_matches('`') == "main"` → 剥离 `static`/`open` 修饰符 → 推入 `lifted` 向量（顶层渲染）
- **层级**: L1 (6 行)
- **测试**: Phase 0 202/202 + 33/33 通过
- **文件**: render.rs `render_regular_class()`
- **备注**: 需用 `safe_name` 去反引号后比较名称，因解析器对 `main` 可能添加反引号


### 2026-07-06 — PARSER_GAP — 泛型 bound `<T : Bound>` 吞掉类型参数表收尾 `>`,函数解析崩坏

- **目标**: 1g full-ksoup (R2)
- **错误**: 9 处 `fun <T : Node> name(...)` 声明渲染成 `func <T, type, b>(: ): Unit` — 函数名丢失、参数名泄入类型参数表,连带 24/45 parse errors
- **根因**: `parse_generic_params` 的 bound 跳过循环在 bdepth==0 遇 `>` 时 `bump()+break`,把**类型参数表**的收尾 `>` 当成 bound 结束符消费掉。外层 depth 回不到 0,持续吞 token。`<T : Bound, U>`(逗号收尾)正常,`<T : Bound>`(`>` 收尾,最常见形态)必崩
- **修复**: (a) bdepth==0 的 `>` 不消费,留给外层循环;`>>` 在 bdepth<=1 时同样留给外层的双层处理。(b) 顺带捕获 bound 编码进 params 条目(`"T <: Bound"`,含嵌套泛型 map_type),render_func 拆出 `<T>` 名字表 + `where T <: Bound` 子句(仓颉无 bound 无法调 T 成员方法)
- **层级**: L1 (parser.rs parse_generic_params ~30 行) + L1 (render.rs render_func gen_suffix/where 拆分 ~20 行)
- **测试**: 新增 210_generic_bound(带 bound 泛型函数 + `Comparable<T>` 嵌套 bound);Phase 0 203/203 + 33/33 通过
- **文件**: parser.rs, render.rs
- **备注**: 1g 45→33 errors。类级泛型 bound(parse_class 932 行路径)仍是丢弃,未报错暂不动

### 2026-07-06 — PARSER_GAP — companion object 内嵌套 class 未解析,成员被误捡为 static

- **目标**: 1g full-ksoup (R2)
- **错误**: nodes_element.cj 20× `'static' and 'override' modifiers conflict` — Element.kt companion 内的 `class NodeList : MutableList<Node>` 的 override 方法被渲染成 `public override static func`
- **根因**: companion 解析循环只认 `fun`/`val`/`var`/`const`,`class` 走 else 分支逐 token bump,类体内的 `fun` 被 companion 循环捡走当静态成员
- **修复**: companion 循环加 `class`/`object`/`interface` 分支 → `parse_class` 后 push 进 members(不进 companion_members),由 renderer 按嵌套类既有机制提升到顶层
- **层级**: L1 (parser.rs companion 循环 ~10 行)
- **测试**: 新增 211_companion_nested_class;Phase 0 回归通过(见 R2 记录)
- **文件**: parser.rs
- **备注**: 已知边界:提升后的嵌套类若引用 companion 属性(Kotlin companion scope 可见)会 undeclared identifier,需 scope 限定(`Outer.prop`)。ksoup NodeList 无此引用,暂不修

### 2026-07-06 — RENDER_GAP — 仓颉关键字逃逸表缺 `operator` 等 Kotlin 合法标识符

- **目标**: 1g full-ksoup (R2)
- **错误**: select_nodes.cj 2 errors — `replaceAll(operator: (T) -> T)`,`operator` 是仓颉关键字
- **修复**: `safe_name` KW 表追加 `operator`/`redef`/`inout`/`synchronized`/`static`(均为 Kotlin 合法标识符)
- **层级**: L1 (parser.rs safe_name +5 词)
- **测试**: 新增 212_cangjie_keyword_idents;Phase 0 205/205 + 33/33 通过

### 2026-07-06 — RENDER_GAP — infer_literal_type 不识别负数字面量与 charArrayOf

- **目标**: 1g full-ksoup (R2)
- **错误**: nodes_entities.cj 2 errors — object `const val empty = -1`/`val codeDelims = charArrayOf(...)` 经 val→field+init 拆分后产出无类型无初始化的 `let empty`
- **根因**: 字段类型标注依赖 infer_literal_type,`-1` 是 Unary(-, IntLit) 不在 match 内;charArrayOf 是 Call
- **修复**: 加 `Unary(±)` 递归推断、`FloatLit→Float64`、`Call(charArrayOf)→Array<Rune>`(与 render_call 的 Rune 数组字面量渲染对应)
- **层级**: L1 (render.rs infer_literal_type +12 行)
- **测试**: 新增 213_object_negative_const;Phase 0 206/206 + 33/33 通过

### 2026-07-06 — PARSER_GAP — enum 条目 trailing comma 后 `;` 被吞 + companion 未按块跳过

- **目标**: 1g full-ksoup (R2)
- **错误**: nodes_entities.cj 2 errors — `fallback,\n;` 后 `public companion object` 的 `public` 被捕为枚举条目(`| public` unknown enum constructor + duplicated modifier)
- **根因**: (a) 条目循环逗号后 `skip_seps()` 连 `;` 分隔符一起吞;(b) 成员循环对 companion 逐 token bump,companion 的 `}` 提前终结循环使 enum 自身 `}` 泄漏
- **修复**: (a) 改 `skip_newlines()`;(b) companion object 整块按括号平衡跳过
- **层级**: L1 (parser.rs parse_enum ~25 行)
- **测试**: 新增 214_enum_trailing_semi_companion;Phase 0 回归见 R2 记录
- **备注**: enum companion 函数(如 CoreCharset.byName)当前整体丢弃,调用点会 undeclared — 待语义轮次做 companion→static 提升

### 2026-07-06 — PARSER_GAP — 无大括号 then 带分号时 else 前探失败

- **目标**: 1g full-ksoup (R2)
- **错误**: nodes_element.cj — Kotlin `if (x) foo();\nelse bar();`(jsoup 移植风格)中 `else` 被当独立语句,渲染出裸 `else`
- **根因**: `skip_newlines_for_else` 只跳换行,被 then 语句尾部 `;` 挡住
- **修复**: 改用 `skip_seps()`(跳 `;`+换行),非 else 时位置回退不变
- **层级**: L1 (parser.rs 1 行)
- **测试**: 新增 215_if_semi_else;Phase 0 208/208 + 33/33 通过

### 2026-07-06 — RENDER_GAP — Kotlin 中位默认值参数违反仓颉命名参数排序

- **目标**: 1g full-ksoup (R2)
- **错误**: select_elements.cj 2 errors — `siblings(query: String? = null, next: Boolean, all: Boolean)` → `query!: ?String = None` 在位置参数之前,仓颉要求命名参数靠后
- **修复**: 声明侧(render_func)与调用侧(fn_params)同规则降级:默认值参数其后还有无默认值参数时,去 `!` 去默认值按位置参数渲染。Kotlin 侧中位默认值本就无法按位置省略,调用点不受影响
- **层级**: L1 (render.rs 两处 ~25 行)
- **测试**: 新增 216_middle_default_param(中位降级 + 尾位保留);Phase 0 回归通过(见 R2 记录)
- **备注**: 构造器参数分支未动(无实例);Kotlin 用具名实参省略中位默认值的调用(如 `siblings(query, next = false, all = true)` 若省 query)会缺参,暂无实例

### 2026-07-06 — PARSER_GAP — trailing-lambda-only 泛型构造被误判为 `<` 比较

- **目标**: 1g full-ksoup (R2)
- **错误**: nodes_entities.cj 2 errors — `ThreadLocal<CharsetEncoder?> { null }`(无圆括号)渲染成二元比较 `ThreadLocal < CharsetEncoder`
- **根因**: `peek_is_generic_ctor` 要求收尾 `>` 后必须是 `(`;泛型构造分支的 parse_args 也只认 `(`
- **修复**: `>` 后允许 `{`;构造分支遇 `{` 时 parse_lambda 作为单实参。误判风险低:`< ... > {` 需全程 ident/sym 且无换行/字面量拦截
- **层级**: L1 (parser.rs 两处 ~10 行)
- **测试**: 新增 217_generic_ctor_trailing_lambda(含 `x < y` 比较防误判);Phase 0 210/210 + 33/33 通过

### 2026-07-06 — HEURISTIC_GAP — `.keys`/`.values` 无条件映射为 `keys()`/`values()`

- **目标**: 1g full-ksoup (R2)
- **错误**: nodes_attributes.cj — 用户类字段 `attributes.keys = keys.copyOf(size)` 被译成非法左值 `attributes.keys() = ...`
- **修复**: 映射加 `!provably_non_collection(base)` 守卫;接收者声明类型可证明为用户类时保留字段访问
- **层级**: L1 (render.rs 2 行改条件)
- **测试**: 新增 218_user_field_keys(用户字段 + HashMap.keys 双向);Phase 0 回归见 R2 记录

### 2026-07-06 — RENDER_GAP — `getOrPut(...)[k] = v` IIFE 非法左值 + 裸 ctor 推断失败

- **目标**: 1g full-ksoup (R2)
- **错误**: nodes_tag_set.cj — `tags.getOrPut(ns) { HashMap() }[tag.tagName] = tag` 的 IIFE 展开作索引赋值左值,cjc 拒绝;且 IIFE 内裸 `HashMap()` 推不出泛型实参
- **修复**: Assign 对 `Index{base: Call}` 特化:(a) getOrPut → statement 级展开 `if (!m.contains(k)) { m[k] = <内联lambda体> }; let tmp = m[k]; tmp[i] = v`,单表达式 lambda 内联使 ctor 从 map 值类型获得推断;(b) 其他 Call base → 提升临时变量(带节点 id 防冲突)。新增 helper `single_expr_lambda_body`
- **层级**: L1 (render.rs Assign 分支 ~40 行 + helper)
- **测试**: 新增 219_getorput_index_assign;Phase 0 回归见 R2 记录
- **备注**: getOrPut 作纯表达式(非赋值目标)时仍走 IIFE,裸 ctor 推断问题依旧——ksoup 无此用法,暂不动

### 2026-07-06 — RENDER_GAP — 可空泛型 bound `<E : Element?>` 渲染出非法 where 子句

- **目标**: 1g full-ksoup (R2, 最后一个 parse error)
- **错误**: nodes_element.cj — `fun <E : Element?> indexInList(...)` → `where E <: Element?`,仓颉无可空 bound 概念
- **修复**: render_func bounds filter 加 `!g.contains('?')`,可空 bound 丢弃 where 条目(保守放宽)
- **层级**: L1 (render.rs 1 行改条件)
- **测试**: 新增 220_nullable_generic_bound;Phase 0 回归见 R2 记录
- **备注**: 后续语义错误已知:indexInList 体内 `===` 被 lexer 退化为 `==`,在无 bound 泛型 E 上非法。R3 候选:`===`/`!==` → refEq/!refEq(类引用相等)

### 2026-07-06 — RENDER_GAP — 嵌套类提升后跨文件类型引用未消歧/未折叠

- **目标**: ksoup-parser (1d, 1g 切片)
- **文件**: engine.rs, render.rs
- **修改**: engine.rs 新增 `apply_nested_lifting` 图归一化 pass：建 (父类, 嵌套名)→提升名注册表；提升名与已有顶层类撞名时按父类名前缀重命名（如 Token.Comment→TokenComment）；对全图类型字符串做限定链折叠。render.rs `render_member` 表达式位同步改写
- **层级**: L2 (engine.rs 新 pass + render.rs 表达式位改写)
- **测试**: 新增 221_nested_class_lifting + proj_nestedlift;Phase 0 214/214 + 34/34 通过
- **备注**: 仅 project 模式生效(见下方经验记录);ksoup 语料该簇错误 151→0

### 2026-07-06 — RENDER_GAP — project 模式注入不存在的 `import std.iterator.*`

- **目标**: ksoup-parser (1d, 1g 切片)
- **错误**: ksoup project 模式 11 个输出文件含 `import std.iterator.*`,仓颉 1.0.5 无 std.iterator 包(Iterator/Iterable 在 core 自动可用),cjc `can not find package 'std.iterator'` 挡住全部语义分析
- **根因**: project.rs `detect_and_gen_imports()` 的启发式分支 `cj_code.contains("Iterator") → import std.iterator.*`。单文件路径(render.rs 头部注入)本无此映射,仅 project 模式受影响
- **修复**: 删除该分支。同表其余映射(std.collection/deriving/sort/convert)与 stdlib_map.rs 的 std.math/std.io 均为真实包,已逐一确认
- **层级**: L1 (project.rs -3 行)
- **测试**: 新增 222_iterator_no_std_import(单文件) + proj_iterimport(project 模式,真正覆盖此 bug);Phase 0 215/215 + 35/35 通过
- **备注**: ksoup project 模式重译后 `std.iterator` 0 处;cjc 全量错误 1595(can not find package 0 处)

### 2026-07-06 — 经验 — per-file 翻译管线丢失跨文件上下文

- **现象**: per-file 翻译管线(translate_1g.py 逐文件调用)对每个 .kt 单独起翻译单元,丢失跨文件上下文
- **结论**: 跨文件语义修复(嵌套类提升消歧、跨文件类型注册等)只在 project 模式(目录输入)生效;per-file 管线测不出这类修复的效果
- **决策**: 1g/1d 测量管线自 2026-07-06 起切换为 project 模式(目录输入直接喂 kotlin2cj)

### 2026-07-06 — STDLIB_GAP — Kotlin stdlib 类型面 stub 注入机制（stdlib-type-surface 行动簇）

- **目标**: 1g full-ksoup (R3) / 1d ksoup-parser (R2)
- **行动簇**: stdlib-type-surface — Kotlin stdlib 类型（Regex/Reader/KClass/Charset 等）无仓颉映射，原样输出致 undeclared。诊断估算 152 错误 + ~80 级联，风险=增量式（数据驱动表，零核心逻辑改动）
- **错误分布（project 模式, tmp_r2 基线, 共 1598 error）**:
  - Regex: 37 (35 undeclared identifier + 2 type name)
  - KClass: 17, Reader: 15, Sequence: 15, MutableIterator: 15
  - ByteArray: 10, IntArray: 9, Charset: 9, CharsetEncoder: 6
  - Appendable: 10, StringReader: 4, Charsets: 1
  - 簇合计 ~148 错误
- **修复（4 处改动，同一机制）**:
  1. **stubs.rs（新文件，13596 字节）** — 数据驱动表 `StubDef { provides, markers, imports, code }`。9 个 stub：REGEX_STUB（Regex+RegexOption+MatchResult，130 行，含 String 扩展）、KCLASS_STUB、READER_STUB（Reader+StringReader）、SEQUENCE_STUB（含 asSequence 扩展）、MUTABLE_ITERATOR_STUB（MutableIterator+MutableListIterator）、BYTE_ARRAY_STUB（type = Array<Byte>）、INT_ARRAY_STUB（type = Array<Int64>）、CHARSET_STUB（Charset+CharsetEncoder+Charsets）、APPENDABLE_STUB（含 StringBuilder 扩展）。`collect_stubs(body)` 扫描已渲染代码体，词边界匹配 marker，`defines_type` 守卫避免与用户自定义冲突，返回 `(imports, code)`。
  2. **project.rs**（+26 行）— `convert_project` 末尾汇总 `all_bodies`，调 `stubs::collect_stubs`，命中则生成独立 `k2cj_stubs.cj`（含 package + imports + code，同包共享避免重复定义）。
  3. **render.rs**（+12 行）— `render_program` 在 `__k2cjRuneSlice` 注入后调 `collect_stubs`，stub_code 追加到 body 末尾，stub_imports 加到 header（仓颉要求 import 在顶部）。
  4. **main.rs**（+1 行）— `mod stubs;` 声明。
- **层级**: L1（纯增量，数据驱动表 + 两处注入点，零核心逻辑改动）
- **测试**: 新增 4 个靶向测试 — 230_regex_basic（Regex matches/find/replace/toRegex）、232_int_array（IntArray 类型别名 + 构造 + 索引）、233_charset（Charset/Charsets/CharsetEncoder）、234_reader_stringreader（StringReader read）。231_byte_array 因 `toByte()` 未映射（另一个翻译 bug 簇）暂删。Phase 0 回归 219/219 single + 35/35 project 全绿 ✅
- **1g 全量测量**: 1598 → 10 error（99.4% 降幅）。stdlib-type-surface 簇 148→0 ✅。自动生成 k2cj_stubs.cj（7109 bytes，9 个 stub 全部命中注入）。
- **剩余 8 parse error（R3 起点）**: 7 × redefinition-of-declaration（document.cj setter 参数名撞成员名）+ 1 × optional-parameter-in-abstract（source_reader.cj）。cjc 遇 parse error 即停，遮蔽语义层。
- **stub 设计原则**: 面最小化——只覆盖测量语料（ksoup 等）实际调用的方法。真实包映射优先（Regex→std.regex），无对应物注入最小 stub。stub 与 `_stubs.cj` 手写机制并存，新机制为数据驱动自动注入。
- **未覆盖的 stdlib 簇（R4 候选）**: MutableMap(7)/MutableList(6)/MutableEntry(5)/AutoCloseable(6)/Entry(3)/IOException(9)/RuntimeException(2)/ArrayDeque(5)/LinkedHashSet(2)/MutableCollection(1)/NoSuchElementException(3) ≈ 50 错误。这些走 map_type 映射（Kotlin MutableList→仓颉 ArrayList 等）而非 stub，或在 stubs.rs 补充新条目。

### 2026-07-07 — RENDER_GAP — interface 方法默认参数未 strip（optional-parameter-in-abstract 行动簇）

- **目标**: 1g full-ksoup (R3) / 1d ksoup-parser (R3)
- **行动簇**: optional-parameter-in-abstract — Kotlin interface 方法 `fun read(offset: Int = 0)` 有默认参数，仓颉 interface 方法不允许默认参数。1 个 parse error。
- **错误**: source_reader.cj:8 `func read(bytes: ByteArray, offset!: Int64 = 0, length!: Int64 = bytes.size): Int64` — interface 方法默认参数，cjc 报 `optional parameter cannot be used in abstract function`。
- **根因**: render_func (line 1068) 已有 open 函数去默认参数的逻辑（`if in_open_class || (is_override && in_open_class)`），但 **render_interface (line 1241) 有独立参数渲染路径，不走 render_func**，interface 方法默认参数没 strip。
- **修复**: render_interface (line 1257) 加默认参数 strip 逻辑——`p.find(" = ")` 去掉 ` = <default>` 后缀。
- **层级**: L1 (render_interface +10 行)
- **测试**: 235_interface_default_param 暂删——翻译器把位置调用 `r.read(0)` render 成命名参数 `r.read(offset: 0)`，但 override 方法用位置参数，导致 `invalid named arguments prefix`。这是另一个 bug 簇（调用点命名参数 vs override 位置参数），不在 R3 范围。Bug 2 修复在 1g 全量验证（source_reader.cj 默认参数被 strip）。
- **副作用**: strip 默认参数后，调用方失去默认参数支持。Kotlin `r.read(bytes)` 不传 offset/length，仓颉需要补值。这是 Bug 2 的深层难题，R4 候选。
- **1g 测量**: optional-parameter-in-abstract error 消掉 ✅。

### 2026-07-07 — SOC — CtorParam var/val 和 func 名冲突未检测（redefinition-of-declaration 行动簇）

- **目标**: 1g full-ksoup (R3) / 1d ksoup-parser (R3)
- **行动簇**: redefinition-of-declaration — Kotlin builder setter `fun escapeMode(escapeMode: EscapeMode)` 参数名/方法名撞成员名。8 个 parse error（7 setter + maxPaddingWidth 被遮蔽后显现）。
- **错误**: document.cj:190 `func parser(parser: Parser)` 撞 `var parser: Parser`（line 10），cjc 报 `redefinition of declaration 'parser'`。7 个同类（escapeMode/charset/syntax/prettyPrint/outline/indentAmount/maxPaddingWidth）。
- **根因**: SOC `resolve_var_func_collisions` (engine.rs:108) 只遍历 `members` 的 `Kind::VarDecl`，不检测 `ctor_params` 的 `CtorParam { kind: Var/Val, name: X }`。Kotlin constructor 参数 `var parser: Parser` 存为 CtorParam（在 `Class.ctor_params`），不是 VarDecl 节点。SOC 解决了 26 个 VarDecl 冲突（_outputSettings/_quirksMode 等），但漏了 CtorParam 冲突。
- **修复**: engine.rs `resolve_var_func_collisions` 末尾加 CtorParam 检测——遍历 `Class.ctor_params`，检测 `CtorParam { kind: Var/Val, name: X }` 是否在 `func_names` 里。冲突则 CtorParam.name 改成 `_X`，全图 NameRef == X 改成 _X（保守名字匹配，CtorParam 无 name_node/dependents）。
- **层级**: L2 (engine.rs +50 行 CtorParam 检测 + 全图 NameRef 级联)
- **测试**: 236_ctor_param_func_collision（单文件，验证 SOC 重命名成员声明 + NameRef 级联：`return mode` → `return _mode`）。Phase 0 回归 220/220 single + 35/35 project 全绿 ✅。
- **1g 测量**: SOC 检测到 23 个 ctor-param 冲突（_escapeMode/_charset/_prettyPrint/_outline/_indentAmount/_maxPaddingWidth/_syntax/_location/_parser/_name/_publicId/_systemId/_pos/_lineNumber/_columnNumber/_nameRange/_valueRange/_start/_end/_preserveTagCase/_preserveAttributeCase/_normalName/_namespace）。8 个 setter redefinition 全部消掉 ✅。
- **副作用**: setter 方法体 `this.escapeMode = escapeMode` 的 `this.escapeMode` 不是 NameRef（是成员访问属性名），SOC 级联没覆盖，`this.X` 没改成 `this._X`。被其他 redefinition 遮蔽（cjc 报到一定数量就停），修完后会显现 `func can not be assigned`。这是另一个 bug 簇（成员访问 render），R4 候选。
- **新显现 8 redefinition（R4 起点）**: 6 × `it`（`let it = _also_it`，also lambda 翻译生成 it 和外部作用域冲突）+ 1 × `attributeKey`（`let attributeKey = settings.normalizeAttribute(attributeKey)`，参数名和局部变量名 shadowing）+ 1 × `append`（同 attributeKey 模式）。这是参数名/lambda it shadowing 簇，R4 目标。

### 2026-07-07 — PARSER — also lambda `let it = _also_it` alias decl 撞外部作用域 it（it-shadowing 行动簇）

- **目标**: 1g full-ksoup (R4) / 1d ksoup-parser (R4)
- **行动簇**: it-shadowing — `also` lambda 内联生成 `let it = _also_it` alias decl，当嵌套在另一个 lambda 的 `it` 作用域里时，`it` 重复声明 → redefinition。6 处 parse error。
- **错误**: ksoup.cj:56 `let it = _also_it`（外部 lambda `{ it => ... }` 的 `it` + IIFE 块体的 `let it`）→ `redefinition of declaration 'it'`。6 处同类（ksoup.cj/node.cj×2/parse_error_list.cj/query_parser.cj/thread_local.cj）。
- **根因**: `build_also` (parser.rs:2081) 生成 alias decl `let <pname> = _also_<pname>`（line 2106-2120），让 lambda 体的 `it` NameRef 指向 `_also_it`。但 `it` 和外部 lambda 的 `it` 参数冲突。Lambda params 是字符串（`Vec<String>`），不是节点，body 的 `it` NameRef 的 `decl` 是 None，render 用 `original`（`it`）。alias decl 让 `it` 在块体有声明，但和外部 `it` 冲突。
- **修复**: 去掉 alias decl。新增辅助方法 `rename_namerefs_in_subtree(root, old, new, decl_node)`（parser.rs），递归遍历 body 子树（用 `children_of`），把 `original == pname`（`it`）的 NameRef 改成 `unique`（`_also_it`），`decl` 指向 `nn`（`_also_it` 声明的 Name 节点）。body 的 `it` 引用直接 render 为 `_also_it`，无需 alias decl。
- **层级**: L2 (parser.rs build_also 重构 -18 行 + 新辅助方法 +25 行)
- **测试**: 237_also_lambda_it（验证 `also` lambda 内联：body 的 `it` → `_also_it`，无 alias decl）。Phase 0 回归 221/221 single + 35/35 project 全绿 ✅。
- **1g 测量**: 6 个 `it` redefinition 全部消掉 ✅。新显现 5 个 undeclared type（MutableMap × 2 + MutableList + Entry + AutoCloseable）——之前被 `it` redefinition 遮蔽，现在显现。这是未覆盖 stdlib 簇（R5 候选）。
- **剩余 8 真 error（R5 起点）**: 3 × redefinition（参数名 shadowing: `let append = append.replace(...)` × 2 + `let attributeKey = settings.normalizeAttribute(attributeKey)` × 1 — Kotlin 允许参数名/局部变量名 shadowing，仓颉不允许）+ 5 × undeclared type（未覆盖 stdlib: MutableMap/MutableList/Entry/AutoCloseable — 走 map_type 映射或 stubs.rs 补充）。

### 2026-07-07 — PARSER — noinline/crossinline/reified 修饰符未识别（inline-fn-param-modifiers 行动簇）

- **目标**: 1f koin-core (R1)
- **行动簇**: inline-fn-param-modifiers — k2cj 参数解析不跳过 noinline/crossinline,parse_generic_params 把 reified 当作泛型参数名本身。Project 模式 1f 翻译首跑只生成 1 .cj 文件。
- **错误**: Koin.kt L107 `noinline parameters: ParametersDefinition? = null,` → PARSE ERROR "期望 ':', 但得到 Ident("parameters")" (project 模式合并行号报 L1046)。
- **根因**: parse_param_nodes (parser.rs:757) 注释明确说"不调用 skip_modifiers() 避免误识参数名关键字(open/internal 等)"——但也跳过了 noinline/crossinline (inline 函数 lambda 参数专用修饰符,不会作为参数名)。另外 parse_generic_params (parser.rs:605) 把 `reified` 当作 Tok::Ident push 进 params,导致 `func f<reified>(...): T` + 'undeclared type name T'。
- **修复**:
  1. parse_param_nodes L759-761: 加 `self.eat_kw("noinline")` + `self.eat_kw("crossinline")` (这两个关键字只在 inline 函数 lambda 参数前合法,不作为参数名,可安全 eat_kw 跳过)
  2. parse_generic_params L605-614: 加 `is_generic_mod = matches!(s.as_str(), "reified" | "out" | "in")` 检查,是则 bump + continue (Kotlin 泛型修饰符,仓颉不支持,跳过)
- **层级**: L1 (parser.rs 两处 +5 行)
- **测试**: 238_inline_param_modifiers (inline + noinline + crossinline + reified 综合测试)。Phase 0 回归 222/222 single + 35/35 project 全绿 ✅
- **1f 测量**: 1f project 模式翻译从 1 → 35 .cj 文件 (修了 noinline/crossinline + reified 跳过后)。剩 3 parse error (typealias + receiver-fn-type 簇)。

### 2026-07-07 — PARSER — typealias 不识别泛型参数 `<T>`（generic-typealias-declaration 行动簇）

- **目标**: 1f koin-core (R1)
- **行动簇**: generic-typealias-declaration — parse_typealias L566 expect_sym("=") 不识别 `typealias X<T> = Target<T>` 的 <T>。
- **错误**: BeanDefinition.kt L148 `typealias Definition<T> = Scope.(ParametersHolder) -> T` → PARSE ERROR "期望 '=', 但得到 Sym('<')" (单文件直接报 L148)。
- **根因**: parse_typealias (parser.rs:563-574) 流程: eat_kw("typealias") → expect_ident (读 "Definition") → **expect_sym("=")** — 但下一 token 是 `<` (泛型参数 `<T>` 的开始)。type_aliases 注册表是 name→target_type 映射 (无泛型),下游用 `X<Arg>` 时由 map_type 兜底;parse 阶段只需保证不报错。
- **修复**: parse_typealias L565 expect_ident 后,若 is_sym("<") 调 parse_generic_params 跳过 `<T>` (params 和 suffix 不使用,只消费 token)。
- **层级**: L1 (parser.rs parse_typealias +5 行)
- **测试**: 239_generic_typealias (typealias StringList + StringMap<V> + IntToString)。Phase 0 回归 223/223 single + 35/35 project 全绿 ✅
- **1f 测量**: 1f project 模式翻译从 35 → 71 .cj 文件 (消掉 BeanDefinition/Callbacks/OptionDSL 的 typealias parse error)。剩 1 parse error (receiver-fn-type 簇)。

### 2026-07-07 — PARSER — 带接收者的函数类型 `ReceiverType.() -> R`（receiver-function-type 行动簇）

- **目标**: 1f koin-core (R1)
- **行动簇**: receiver-function-type — parse_type_raw 不识别 Kotlin 带接收者的函数类型语法 `ReceiverType.() -> R`。
- **错误**: Module.kt L84 `fun scope(qualifier: Qualifier, scopeSet: ScopeDSL.() -> Unit)` → PARSE ERROR "期望 ')', 但得到 Sym('.')" (合并源 L304,Module.kt + FactoryOf.kt 两文件最小复现)。
- **根因**: parse_type_raw (parser.rs:2760-2786) 函数类型分支处理 `(A, B) -> R` 标准形式,但不识别 `ReceiverType.() -> R`。parse_type_raw L2787 expect_ident 读 "ScopeDSL",L2789 `while is_sym(".") && peek_next_is_ident` —— 但下一 token 是 `(` 不是 ident,不消费 `.`,返回 "ScopeDSL"。parse_param_nodes 把 "ScopeDSL" 当作参数类型,expect_sym(")") 期望 `)` 但得到 `.`。
- **修复**: parse_type_raw L2787 expect_ident + 嵌套类型 (`Outer.Inner`) + 泛型实参 (`<T>`) 处理后,新增检查 `is_sym(".") && toks[pos+1] == Sym("(")`。是则 bump 消费 `.`,把已读的 ReceiverType 当作函数类型第一个参数,转入 `(ReceiverType, ...) -> R` 解析 (仓颉函数类型支持此形式)。
- **层级**: L1 (parser.rs parse_type_raw +25 行新分支)
- **测试**: 240_receiver_function_type (Builder.() -> Unit + Builder.() -> Int 双向)。Phase 0 回归 224/224 single + 35/35 project 全绿 ✅
- **1f 测量**: 1f project 模式翻译从 35 → 71 .cj 文件 (消掉 Module/KoinApplication/KoinConfiguration/ModuleDSL/ModuleExt 的 receiver-fn-type parse error)。剩 1 parse error (val <E : Enum<E>> Enum<E>.qualifier 带泛型扩展属性) + 9 编译错误。
- **副作用**: 翻译产物 `extend Module<R,T1,T2,...>` (Module 非泛型类,语义错误) — 这是 parse_fun L710 generic_params.clear() 的 bug,清空了函数自身泛型参数。R2 候选 (1f 编译错误的潜在根因之一)。

### 2026-07-09 — 指标口径修正 — 1g "10 errors" 是 cjc 打印截断误计（非修复，口径决策）

- **目标**: 1g full-ksoup（R2-R4 测量全部受影响）
- **发现**: cjc 默认 `--error-count-limit 8`——日志末行 "1460 errors generated, 8 errors printed"。R2-R4 把"打印出的 8 个 error 块 + 2 条 cjpm Error 消息"数成 10。真实错误数 R4 时为 1460。
- **决策**: 自 R5 起所有 target 测量管线在 cjpm.toml 加 `compile-option = "--error-count-limit all"`，以 "N errors generated" 为唯一口径。方向是把口径改严（数字变难看），与"改口径让数字好看"的风险相反。**2026-07-09 用户人工会签批准**（核实 target_1g_r5 / target_2a 管线均已带该选项）。
- **教训**: "剩 10 个错" 的收敛叙事全部作废；1g 实际仍有 ~1400 语义错误，语义战役未打完。任何 "X errors printed" 截断输出不得直接当总数。

### 2026-07-09 — STDLIB_GAP+RENDER — undeclared-supertype 簇（Entry/AutoCloseable/MutableList/MutableMap 父类型声明失败）

- **目标**: 1g full-ksoup (R5)
- **行动簇**: 5 个核心类的父类型未声明（`Attribute <: Map.Entry`、`CharacterReader <: AutoCloseable`、`NodeList/Nodes/ParseErrorList <: MutableList`、`IdentityHashMap <: MutableMap`），类声明失败级联全文件。
- **修复**（4 处，全部 235/235 single + 36/36 project 回归通过 ✅）:
  1. **parser.rs parse_class 父类型位**: 限定名折叠 `Map.Entry`→`Entry`、`MutableMap.MutableEntry`→`MutableEntry`（stdlib 嵌套接口，engine 嵌套提升注册表不覆盖）。
  2. **parser.rs map_type**: 泛型分支 `Map.Entry<K,V>`/`MutableMap.MutableEntry<K,V>` → 元组 `(K, V)`（仓颉 HashMap 迭代元素类型）；非泛型分支裸名折叠同父类型位。
  3. **stubs.rs**: 新增 4 个 stub — AutoCloseable（带 `func close(): Unit`）、MutableList（非泛型 marker）、MutableMap+MutableCollection、Entry+MutableEntry（marker，父类型位泛型实参已被 parse 丢弃故用非泛型）。
  4. **render.rs + heuristics.rs**: `override_provably_unmatched` — 类的全部父类型都是已知成员集接口（marker=无成员、AutoCloseable={close}、ToString={toString}）且成员名不命中时剥掉 `override`（否则 marker 接口一进来 error-71 原地不动）。坑: 嵌套类（Element 内 NodeList）成员的祖父节点是外层类，判定所属类必须先查直接父节点再查祖父。
- **层级**: L1×3 + L2（override 剥离跨 render/heuristics）
- **测试**: 241_autocloseable、242_mutable_list_marker、243_map_entry_supertype
- **1g 测量**: 1458 → 1411（全量口径）。undeclared-supertype 5 根因清零；override 簇 71→36；undeclared type 44→26（剩 ArrayDeque/IOException/FilterResult/T 等，R6 候选）。

### 2026-07-09 — PARSER — 合并翻译错误恢复 depth 计数 bug（错误点在嵌套花括号内时丢弃后续全部文件）

- **目标**: 2a kotlinx-datetime (R0 基线测量被阻断时发现)
- **错误**: project 模式翻译 55 文件只出 1 个。DateTimePeriod.kt 的多行函数类型带命名参数 `construct: (\n years: Int, ...\n) -> T` parse 失败后，恢复逻辑跳过后续 50+ 文件。
- **根因**: parser.rs parse_program 错误恢复以 `depth == 0` 时遇 `package` 为边界，但 depth 从错误点（嵌套花括号内）起算 0，退出外层花括号后变负 → 永不等于 0 → 跳到 EOF。
- **修复**: 边界判定 `depth == 0` → `depth <= 0`（parser.rs +1 行语义 +注释）。
- **层级**: L1
- **测试**: proj_parserecovery（Choker.kt 含不可解析构造 + Ok.kt/Main.kt 验证后续文件存活）
- **2a 测量**: 翻译 1 → 53/55 文件。11 个 PARSE ERROR 点（多行函数类型带命名参数为首簇）。编译层: 2 文件 lex 错（未闭合字符串/插值）遮蔽全部；排除后 109 错仍全为 parse 层（44 泛型位关键字泄漏 + 29 modifier 冲突 + 14 unexpected modifier + 10 顶层 var 未初始化）。语义层未揭示 — 2a R1 候选簇。

### 2026-07-09 — STRATEGY UPDATE — API-first：真实包映射优先原则前移为决策时规则

- **变更**: 本文件 2026-07-06 条"stub 设计原则"里的事后总结——"真实包映射优先（Regex→std.regex），
  无对应物注入最小 stub"——升格为决策时规则，落三件套：
  1. **修复手段偏好序重构**（autonomous-strategy.md）：按错误家族分列；A 族（符号/类型缺失）内
     std 映射 > stdx/二方库 > TPC 三方库 > 最小 stub 兜底。旧扁平 7 条序（stub 排第 1）废弃保留对照。
  2. **查证门**（external-knowledge.md 3.5）：写 stub/手写库前必查查证链①②③④⑤（索引级，
     ≤5 次读取）；诊断簇 JSON 加 `api_check` 字段（diagnostician），fix-history 条目加"查证"行，
     新增 stub 未附查证记录不得提交（fixer 约束）。
  3. **知识库注册表**（knowledge-registry.md，新建）：全部知识库唯一权威清单 + 查证链位次 +
     接入协议（单文件入口索引/插入位次/重叠仲裁/双环境路径）；新增知识库=加一行，流程不改。
- **动机**: stub 是永久负债（终身跟随仓颉 stdlib 演进 + 语义漂移），映射维护费≈0——同为"纯增量"，
  负债量级不同。旧序把 stub 排第 1 只看了改动增量。三方库映射不无条件优于 stub：外部 git 依赖
  引入可复现性/版本/cjc 兼容/网络四个新风险面，面宽（整库级）完胜、面窄过知止之秤。
- **存量整改**: 5 个手写重实现 stub（READER/KCLASS/MUTABLE_ITERATOR/APPENDABLE/CHARSET）+
  R5 4 个 marker stub 登记为剪枝轮候选（state「剪枝轮候选」节），译器代码改动不随本次文档变更。
- **配套改动**: SKILL.md（API 优先原则 + 经济学三笔 + 外部知识表）、k2cj-fixer.md、
  k2cj-diagnostician.md（风险阶梯细分：增量式-映射 < 增量式-stub）、kotlin-cangjie-patterns.md、
  .claude/CLAUDE.md 关键规则。

### 2026-07-09 — STRATEGY UPDATE — 两层节奏显式化（战术贪心 + 战略校准）

- **来源**: ① 口径事故（R2-R4 基于误计"10 errors"规划三轮）② 1g R5 级联预测误差（预判 undeclared 父类型大崩塌，实际净降 47，误差 3-5 倍）③ 遮蔽层顺序在 1e/1g/2a 三 target 复现。
- **变更**: autonomous-strategy.md 新增「两层节奏：战术贪心 + 战略校准」总纲节——战术层保持每轮重诊断贪心选簇（禁止跨轮沿用旧分布）；战略层维护三张地形图（遮蔽层路线图 / 经济曲线与天花板 / 组合投资排序），每 5 轮或 surprise（预测误差 >3 倍 / 平台期 ≥2 轮 / 口径存疑）触发校准，口径存疑时修仪表优先于走棋。反模式显式禁止：基于未揭示层的数字做多轮规划、基于打印截断数计算有效率。
- **联动**: SKILL.md auto mode 每轮流程加 8.5 步（战略校准，与防刷软柿子审计同轮）；自主循环判据代码块后加指针。

### 2026-07-09 — PARSER+RENDER — mutable-collection-delegation 簇（Kotlin 接口委托 `: MutableList<T> by delegate` 落地为真实 `List<T>` + 转发成员）

- **目标**: 1g full-ksoup（R5 遗留：Nodes/Elements/NodeList/ParseErrorList 的 MutableList marker 空接口导致成员全 undefined）
- **行动簇**: mutable-collection-delegation — Kotlin 接口委托 `class Nodes<T> : MutableList<T> by delegateList` 的委托被 parser 丢弃（旧代码 parse_class 见 `by` 只跳 token），父类型又被打成 R5 的空 marker `interface MutableList {}`；结果 `open class Nodes<T> <: MutableList & ToString` 体内 size/add/get/indexOf/addAll 全 undefined，级联全文件（估 ~145 error）。
- **查证门（过，方向=真实 API 映射优先）**: 写探针 `class MyList<T> <: List<T> {}` 用 cjc 1.0.5 编译，从 "unimplemented interface" 报错反推 `List<T>`（继承 `Collection<T>`）在 1.0.5 的精确必需面 —— `prop first/last/size`、`func get(Int64): ?T`、`operator func [](Int64): T`、`operator func [](Int64, value!: T): Unit`、`add(T)` / `add(T, at!: Int64)` / `add(all!: Collection<T>)` / `add(all!: Collection<T>, at!: Int64)`（4 重载）、`remove(at!: Int64): T` / `remove(range: Range<Int64>): Unit`（2 重载）、`removeIf((T)->Bool)`、`clear()`、`isEmpty(): Bool`、`iterator(): Iterator<T>`、`toArray(): Array<T>`。第二探针（backing ArrayList + 全转发）编译+运行零错，锁定精确签名。
- **修复**（4 文件）:
  1. **node.rs**: 新增 `struct SuperDelegation { supertype, type_args, delegate: NodeId }`；`Kind::Class` 加字段 `supertype_delegations: Vec<SuperDelegation>`；`children_of` 纳入 delegate 节点。
  2. **parser.rs**: ① 新增 parser 字段 `suppress_trailing_lambda`，在 parse_postfix 三处尾随 lambda 分支（`.method {`、裸 `ident {`、parse_args 的 `(...)  {`）加门控，防止 `by delegateList {` / `by mutableListOf() {` 把类体 `{...}` 当尾随 lambda 吞掉（出错也复位，避免泄漏后续文件）。② parse_class 父类型位泛型跳过循环改为**捕获顶层类型实参原文**（`MutableList<T>`→"T"）。③ `by` 处理：`MutableList`/`List` 之后的 `by` 解析委托表达式并记入 `supertype_delegations`（不推 interfaces）；其余 `by`（非集合）保持旧跳过行为。
  3. **render.rs**: 新增 `render_list_delegations()` —— 父类型渲染为真实 `List<T>`（`std.collection`，替代 marker）；委托目标为裸标识符（`by delegateList`，指向构造参数字段）时直接转发、否则合成 `private let __k2cj_delegate: ArrayList<T> = <expr>` 后备字段（`by mutableListOf()` 场景）；生成探针查明的整套转发成员，`is_open` 时带 `public open`。用户已 override 的成员按 (名字, 参数个数) 去重（`iterator`/`clear`/`removeIf`/`get`/`add(element)`/`remove(at!)`/`prop first`/`last`/`size` 命中即跳；命名参数/操作符签名恒生成不去重）。engine 分发处线程新字段。
  4. **stubs.rs**: 不改 —— MutableList marker 仅由**直接实现型**（`: MutableList<T>` 无 `by`，如 242）继续按需注入；by-委托路径不再引用它。向后兼容保留。
- **层级**: L2（parser.rs + node.rs + render.rs 三文件协同；render 新增 ~110 行 helper）
- **测试**: 244_list_delegation（`class MyList : MutableList<String> by mutableListOf()` + add/size/total/迭代，合成后备字段路径）、245_list_delegation_field（`open class Bag<T>(val backing) : MutableList<T> by backing` + `override iterator` + `[]`/clear，裸标识符转发 + open + override 去重路径）。两例翻译→cjc 编译→运行→比对全绿。抽查 242_mutable_list_marker（直接实现型未受影响）、243_map_entry_supertype、237_also_lambda_it 三旧例 exact-match 通过。
- **ksoup 抽查**: 单文件翻译 select/Nodes.kt → `open class Nodes<T> <: List<T> & ToString`（marker 消失），转发成员 get/[]/[]set/add×4/remove(range)/isEmpty/toArray/prop size 全部生成并转发到 `delegateList`（构造参数，无合成后备字段）；用户 `override iterator()`（MutableIterator<T>）/`clear()`/`removeIf(...)`/`first()`/`last()`/`remove(element)` 命中去重不重复生成。全量 ksoup 编译由 orchestrator 测量。
- **已知残留/风险**: ① 去重按 (名字,参数个数) 保守 —— 用户 `remove(element:T)`(arity1) 会连带跳过合成 `remove(at!:Int64)`（签名其实不冲突），导致 List.remove(at) 面未满足；直接实现型（NodeList/ParseErrorList 若非 by 委托）本轮未处理，仍走 marker（下轮候选）。② `MutableMap`/`IdentityHashMap` 侧本轮未动（scope 控制）。③ type_args 捕获只取顶层 Ident（`MutableList<Foo<Bar>>` 退化为 `List<Foo>`），集合委托实参简单故不影响。

### 2026-07-09 — PARSER+RENDER+HEURISTICS — mutable-collection-delegation R7 收尾（List<T> 四接缝 + 父类泛型保留）

- **目标**: 1g full-ksoup（R6 铺轨后 List<T> 委托类残留四个接缝，全量 1403 errors）
- **行动簇**: mutable-collection-delegation R7 —— R6 让 `class Nodes<T> : MutableList<T> by delegateList` 落地 `<: List<T>` + 转发成员（1411→1403，net -8），但接缝未合：prop first/last 撞名、removeIf 返 Bool 非子类型、override 未按 std List 成员集剥离、子类 Elements 父类泛型丢失级联。
- **根因与修复**（5 处，全量 238/238 single 翻译+编译、231/231 有 expected 用例通过 ✅）:
  1. **父类泛型保留**（parser.rs parse_class，最大单点收益）: `class Elements(...) : Nodes<Element>(delegateList)` 旧渲 `<: Nodes`（裸泛型）→ cjc 报 "generic type should be used with type argument" 并级联子类全部 override 失配（探针 probe8 复现）。父类型位捕获的 type_args 附回：`superclass = Nodes<Element>`。顶层类型实参逐个过 map_type（`Int`→`Int64`）。
  2. **seam 1 — first/last→prop**（render.rs render_func）: std `List<T>` 要求抽象 `prop first/last`；用户 0 参 `first()/last()`（List-iface 类）转渲染为 `prop`（body 作 getter 保留）。call site `.first()/.last()` 已被 stdlib_map 映射为 `[0]/[size-1]`（ksoup 内 0 处裸 `.first()`），无需改调用点。
  3. **seam 2 — removeIf→Unit**（render.rs render_func）: 接口 `removeIf(...): Unit`，Kotlin 用户返 Bool 非子类型。List-iface 类的 removeIf 强制返 Unit，原 body 包进立即执行 lambda `let _ = { => <body> }()` 丢弃布尔（lambda 内 return 从 lambda 返回，probe10 验证）。
  4. **seam 3 — override 按 List 成员集剥离**（heuristics.rs override_provably_unmatched）: 新增 List/MutableList 委托类识别（`supertype_delegations` 命中且无 superclass）→ 仅 `iterator/next/hasNext`（Iterable/Iterator 面）保留 override，其余（equals/hashCode/set/removeAt/removeAll/retainAll/remove(element)/clone 等 Kotlin 签名与 Cangjie List 面不匹配者）一律剥离为普通方法。子类（Elements，有 superclass）走原逻辑保留 override（父类泛型修好后合法覆盖 Nodes 开放方法）。新增 helper `owning_class_of` / `is_list_iface_class`（后者递归查 superclass 支持子类判定）。
  5. **remove(at!) 去重键改 None**（render.rs render_list_delegations）: `remove(at!: Int64)` 命名参数与用户 `remove(element: T)` 位置参数签名不同、不冲突——从 (remove,1) 去重键改为恒生成，避免用户 remove(element) 误伤去重致 `unimplemented remove`（Nodes 命中此坑）。
- **层级**: L2（parser.rs + render.rs + heuristics.rs 三文件协同）
- **seam 4（直接实现型合成 backing）未实现**: ksoup 唯一直接实现类 NodeList（Element.kt:1946 `class NodeList : MutableList<Node>`）有自己的存储 `list: ArrayList<Node>` + 引用它的 Kotlin override（add/remove/addAll 返 Boolean），非"无存储"清洁场景；且 Kotlin 集合方法返 Boolean 与 Cangjie List 面（Unit/T）存在根本阻抗（probe6 证 `add(x): Bool` 带 override 报 return-type-not-subtype）。当前保持 `<: MutableList` marker（空接口，override 被 marker 规则剥离，正常编译）。ParseErrorList（coordinator 举例）实为 `by mutableListOf()` 委托，R6 已修（隔离编译 pel_test.cj 零错，R6 log 该条系级联误报）。故 seam 4 在 ksoup 无清洁靶点，按 Rule 2 不做投机实现，记为残留。
- **测试**: 246_list_delegation_overrides（委托类 + 用户 override first()/last()/removeIf()，覆盖 seam 1+2）。244/245/242/243/237 抽查 exact-match 通过。
- **1g 测量**: 1403 → 1355（全量口径，net -48）。override "does not have an overridden function" 43→28（清掉 15 个 Nodes/Elements List 项；余 28 为其他 marker/iterator 类的 equals/hashCode/clone/next/hasNext，非本簇）。nodes.cj 39→33、elements.cj 75→43、parse_error_list 4→4、element.cj 234→232；attributes/tag 等非 List 文件计数不变（无回归）。
- **已知残留/风险**: ① NodeList 直接实现型（own storage + Boolean-return override 阻抗）需专门处理，R8 候选。② 剩余 28 override 错为其他 marker（MutableIterator next/hasNext、自定义 iterator）+ equals/hashCode/clone，独立簇。③ 父类泛型捕获仅取顶层 Ident（`Base<Map<K,V>>` 退化为 `Base<Map>`）；ksoup 父类泛型简单（Nodes<Element>）不受影响。④ elements.cj 余 43 错为 LinkedHashSet 未声明 / ArrayList 构造 / addAll / 泛型推断等独立问题，非四接缝。

### 2026-07-09 — RENDER_GAP — interpolation-multiline（字符串插值内多行块折叠为单行）

- **目标**: 2a kotlinx-datetime（core/common/src）；R1 基线被 2 文件 4 个 lex 错阻断全部语义诊断。
- **行动簇**: interpolation-multiline —— `LocalTimeFormat.kt`/`UtcOffsetFormat.kt` 的 `toString` 里 `${x ?: "??"}` / `${y?.let{...} ?: "?"}` 之类 Kotlin 模板表达式，render 后插值段 `${...}` 内塞进**多行** if-let 块（pretty-print 带换行+缩进）。仓颉单行字符串不允许换行 → `unterminated string interpolation` / `unterminated single-line string`，词法层直接崩，挡住下游全部诊断。
- **根因**: render.rs `Kind::StrTemplate` 分支渲染 `TemplatePart::Expr` 时直接 `${et}` 拼接，`et` 为子表达式已渲染文本，可含换行（多行块）。仓颉以换行**或** `;` 分隔语句——单纯去换行会让相邻语句粘连（`let neg = negValue if(neg)` → parse error）。
- **修复**（render.rs 单文件，L1）:
  1. **`Kind::StrTemplate` 分支**（render.rs:~204）: `TemplatePart::Expr` 渲染结果过 `fold_interp_expr()` 再拼入 `${...}`。
  2. **新增自由函数 `fold_interp_expr`**（render.rs:10，~55 行含辅助 `next_token_is_continuation_kw`）: 把插值表达式内换行+行首缩进折叠为单行。多数换行折成 `;`（保留语句边界），续行处折成空格——续行判据：下一 token 为 `else/catch/finally` 关键字、或换行前/后为续行运算符/标点（`{([,.?:=+-*/%<>&|!` / `).],?:=+-*/%<>&|!`）、或下一字符是 `}`（块闭合）。行内空白（含单行字符串字面量内容）原样保留。含 `"""` 多行字面量则跳过折叠、保原样 fail loud（当前 render 不产 `"""`，防御性）。
- **cjc 1.0.5 探针**（4 发，锁定分隔符规则）: ① `;` 作语句分隔合法；② 空块首 `{ ;` / 末 `; }` 冗余分号被容忍（`{ "val"; }` 仍产 String 值，不退化 Unit）；③ **`} ; else` 致命**（`expected expression, found else`）——故续行关键字前必须空格；④ `if(let Some..){} ?? d`（即 `?.let{} ?:` 的渲染形）本身是**独立语义 bug**（if-let 产 Unit 不可 `??`），本簇不管，由重译揭示。
- **层级**: L1（render.rs 单文件，纯 render 层，无 parser/node 改动）
- **测试**: 247_interp_multiline（`sign(Boolean?)` 嵌套 if 触发 smart-cast `let neg = ...` 多语句块走 `;` 路径；`grade(Int)` 首分支 `val g="A"; g` 多语句块走 `;` 路径）。翻译→cjc 编译→运行→exact-match 全绿（`-end/+end/ end/[A]/[B]/[F]`）。用 if/else 等价形而非裸 `?.let{} ?:`，因后者触发上述独立语义 bug 不可运行。抽查 213/237/244（含 244_list_delegation）exact-match 通过，无回归。
- **2a 测量**: R1 4 lex 错（`unterminated`）→ R2 **0 lex 错**清零。两 culprit 文件 `toString` 均单行化（local_time_format.cj:97、utc_offset_format.cj:150）。揭示下游 111 parse/语义错（全量），top 簇：generic type name after `<X>`×44、override/static modifiers conflict×29、unexpected modifier override top-level×14、top-level var 未初始化×11、function body missing×6。lex 阻断解除，语义层暴露成功。
- **已知残留/风险**: ① `?.let{} ?:` → `if-let {} ?? d` 是独立语义 bug（下轮候选，2a 111 错中的一部分）。② 折叠分隔符判据基于字符/关键字启发式，非完整词法分析：极端情形（语句真以续行运算符集内字符结尾、或方法链跨行 `foo\n.bar()`）可能误判分隔符；ksoup/datetime 的插值块为 pretty-print 规整块，实测未触发。③ 只处理插值表达式文本换行，不做语句级提升（L2，本轮不做）。

### 2026-07-10 — PARSER+RENDER — 2a R3 三簇打包（类级 variance + override/static + expect body）

- **目标**: 2a kotlinx-datetime（core/common/src）；R2 基线 111 errors（lex 清零后暴露的 parse/语义层），三个正交 L1 parse 簇一并处理。
- **行动簇**（3 簇，各自独立，翻译+编译全绿）:
  - **簇 A — 类/接口级泛型 variance 关键字泄漏（44 错）**: `interface Predicate<in T>` / `class Box<out T>` 的方差修饰符 `in`/`out` 被 parse_class 泛型解析当成**参数名**push、真名 T 被丢，渲染成非法的 `<in>` / `<out>`。**根因**: 1f R1 只修过函数级 parse_generic_params（跳过 reified/out/in），类级 parse_class 泛型循环（parser.rs:~1046）没走同一逻辑。**修复**（parser.rs 单点）: parse_class 泛型参数循环在 `Tok::Ident` 分支加 `depth==1 && matches!(id, "in"|"out"|"reified")` 跳过（消费后不 push、不动 expect_name），与函数级同逻辑。
  - **簇 B — override/static 冲突 + 顶层 override（29+14=43 错）**: ① object 单例（`object Truth : Predicate`）成员静态化后带 `static public override func` → `'override' and 'static' modifiers conflict`（×29）；② 类体被截断后成员泄漏到顶层的函数带 `public override func`（×14，见簇 C 根因）。**修复**（render.rs 三处）: (a) render_singleton 静态化分支 `format!("static {}", strip_modifier(&mt, "override"))`；(b) render_regular_class companion 静态化分支追加 `strip_modifier(&mt_no_open, "override")`；(c) render_func 计算 `is_top_level = owning_class_of(id).is_none()`，顶层作用域函数无条件剥 override（仓颉 override 仅限类/接口成员）。
  - **簇 D — expect 函数缺 body（6 错）**: Kotlin 多平台 `internal expect fun safeMultiply/safeAdd/UtcOffset/localDateTimeToInstant`（common 无 body、actual 在未纳入的平台目录）渲染成无体函数 → `body of function is missing`。**选择 stub 而非跳过**（调用面广：safeMultiply/safeAdd 在 DateTimeUnit/DateTimeComponents/DateTimePeriod/math 多处调用，跳过会产生更多 undeclared）。**修复**（parser.rs parse_fun）: `mods` 含 `expect` 且非扩展（receiver_type.is_none）→ 渲染为 `throw Exception("expect stub: <name>")`（throw 类型 Nothing 兼容任意返回类型）；**并按映射后签名去重**（新增 parser 字段 `expect_fn_sigs: HashSet<String>`）——Kotlin 重载 `safeMultiply(Long,Long)`/`(Int,Int)` 在仓颉均折叠为 `(Int64,Int64)`，两个存根会撞 redefinition，故第二个丢弃（返回 `Kind::Raw("")` 空节点）。扩展型 expect fun（`Instant.toLocalDateTime`、`UtcOffset.Companion.parseOrNull`）渲染为空体 extend 不报 body-missing，本轮不动。
- **层级**: L1×3（parser.rs 2 处 + render.rs 3 处，各簇互不依赖；无 node.rs/接口改动）
- **测试**: 248_class_variance（`Box<out T>`/`Sink<in T>`/`Bridge<in A, out B>` 直接实例化，验证真名 T/A/B 提取）、249_expect_fun（4 个 expect 重载折叠去重为 2 存根 + throw 捕获 → mul-stub/add-stub，直接验证去重路径）、250_companion_static（companion 静态工厂 add/zero/mul 守护静态化路径不回归）。三例翻译→cjc 编译→运行→exact-match 全绿。全量 single 回归 239→242（+3 新例）通过，无回归。
- **2a 测量**: 111 → **18**（net -93，全量口径 `--error-count-limit all`）。三簇模板**全部清零**：`keyword 'in'`×44→0、`modifiers conflict`×29→0、`top-level override`×14→0、`body of function missing`×6→0，且**零新增同模板错误**（predicate.cj Truth 静态化后 `<: Predicate`（raw 无泛型实参）cjc 未报 conformance 错）。残留 18 = 全部为 R2 已存在的非目标模板（top-level var 未初始化×11 + 孤儿 companion×2 + emptyIntermediate×1 + unclosed `(`×1 + expected `;`×1 + 顶层 `extend`×1 + `sign` 缺类型×1）。
- **簇 C 查证结论（只查证不冒进，未修）**: `variable in top-level scope must be initialized`×11（year_month.cj/local_date_range.cj/year_month_range.cj）**非** lateinit / const-drop，根因是 **`expect class` + 分离式 constructor 体的解析崩溃**。源 `public expect class YearMonth` 换行后 `public constructor(year, month) : Comparable<YearMonth> { val year: Int; ... }`（Kotlin 多平台 expect class 声明成员的特殊语法）被 parser 误解析为**空 `class YearMonth {}` + 构造体成员泄漏到顶层**（属性→无初始化的裸 `let year: Int64`，方法→顶层 `override func`——即簇 B② 的 14 个来源）。这是**结构性解析问题**（expect class 体归属 + 成员归位），牵扯声明结构重组，非安全 L1，按 task 判据（"牵扯类型推断/初始化顺序，不修"）**记为下轮候选**。修簇 C 需在 parser 层识别 `expect class Name` 后跟分离 `constructor(...) {body}` 的模式，把 body 作为类成员归位——预计一并消除簇 C 的 11 + 簇 B② 残留链 + 孤儿 companion。
- **已知残留/风险**: ① 簇 C（expect class 分离构造体，结构性，R4 候选，预计连带清 15+ 错）。② object/companion 实现接口（`object : Interface`）静态化后接口 conformance 面理论上不满足（static 成员无法满足 interface 实例方法），本轮 predicate.cj 因 `<: Predicate` 用 raw 无泛型实参形式 cjc 恰好未报错，但泛型实参保留修好后（另一 pre-existing bug：supertype 类型实参丢失）可能暴露 conformance 错——object-implements-interface 是更深的架构阻抗，超 L1。③ expect 去重按 `name(cjType,...)` 键作用于整个 project（parser 实例跨文件），理论上不同文件同名同签 expect 会误合并，但 expect 语义本就单 actual，合理。④ 供参考的第二个 supertype-generic-drop bug（`class Truth <: Predicate` 丢 `<Any>`）本轮未动，独立簇。

### 2026-07-10 — PARSER+RENDER+NODE — 2a R3 簇 C 真根因（expect-class 分离构造体解析崩溃 + 成员存根渲染）

- **目标**: 2a kotlinx-datetime（core/common/src）；R3 基线 output/target_2a_r3 = 18 errors（其中 11 top-level var uninit + 2 孤儿 companion 为簇 C，前一轮查证定位、判为下轮候选）。本轮攻簇 C 真根因。
- **根因**（两层，缺一不可）:
  1. **解析崩溃**: `YearMonth.kt` 的 `public expect class YearMonth` 采用 Kotlin 多平台**分离式主构造器**语法——类名在一行、`public constructor(year, month) : Comparable<YearMonth> { ...成员... }` 在下一行（中隔 KDoc/换行）。`parse_class` 在探测主构造器前的 `self.skip_modifiers()` **不跳换行**，故类名后紧跟 `Tok::Newline` 时 skip_modifiers 立即返回、`eat_kw("constructor")` 失配、`eat_sym("(")` 失配 → 主构造器与 `: 超类型` 与 `{ 类体 }` 全部未消费，产出空 `class YearMonth {}`，整个类体作为**顶层声明**泄漏（`val year: Int` → 无初始化裸 `let year`（簇 C 的 11 uninit）；`fun`/`override` → 顶层函数（**上一轮簇 B② 的 14 个 top-level override 来源**）；`companion` → 孤儿）。
  2. **语义存根缺失**: 即便修好解析、成员归位，`expect class` 成员均为**声明无体**（`val year: Int` 无初始化、`fun toEpochDays(): Long` 无 body）。cjc 1.0.5 探针证实：类内无体成员方法报 `function can not be abstract`、无初始化字段报 `uninitialized member variable not initialized in constructor`。R3 中这些错误被**同包 parse 错误掩盖**（cjc 遇 parse 错即中止语义分析）——单纯修解析会让全部 7 个 expect class 的语义错**集中爆发**。故解析 + 存根渲染必须同时做。
- **修复**（3 文件 L2）:
  1. **parser.rs — 分离主构造器解析**（parse_class）: 主构造器探测改为 `save pos → skip_newlines + skip_modifiers + skip_newlines → **仅当** is_kw("constructor") 或 is_sym("(") 才消费主构造器；否则回退 pos`。回退保证 `class Foo\nfun bar()`（无主构造器、下一个是顶层声明）不被误吞修饰符（原地保留 `public fun bar`）。
  2. **node.rs + parser.rs — is_expect 贯通**: `Kind::Class` 加 `is_expect: bool`；parse_class 从 `mods` 计算 `is_expect = mods.contains("expect")`。
  3. **render.rs — expect 成员存根渲染**: render_class/render_regular_class 线程 `is_expect`；成员循环中 is_expect 时经新增 helper `render_expect_member` 渲染——**字段(val/var)→抛异常的计算 prop**（`public [static] [mut] prop x: T { get() { throw } [set] }`，惰性——仅访问时抛，规避静态字段 eager 初始化在程序启动即崩）；**方法/companion 方法→`func ... { throw Exception("expect class stub") }`**（companion 加 `static`）；**次构造器→`init(...) { throw }`**。主构造器（ctor_params 为 Plain，无 val/var）渲染为空体 `init(...) {}`（无存储字段故合法）；扩展函数/嵌套类仍走原提升逻辑。
- **层级**: L2（parser.rs + node.rs + render.rs 三文件协同；render 新增 ~70 行 helper）。选 stub 而非跳过（与 R2 expect fun 一致哲学）：common 侧无实现，构造成功、成员访问抛存根异常，让下游引用（`LocalDate.MIN`、`YearMonth(y,m)`、`.orNull()` 等）全部可解析编译。
- **测试**: 251_expect_class（`expect class Widget` + 分离 `public constructor(id)` + val 属性 + 次构造器 + companion + 方法；构造主 ctor 成功、访问 prop/调用方法抛存根→捕获→prop-stub/method-stub）。翻译→cjc 编译→运行→exact-match 全绿。
- **2a 测量**: R3 18 → **R4 5**（net -13，全量口径）。簇 C 完全清零：top-level var uninit ×11→0、孤儿 companion ×2→0。**7 个 expect class 文件全部编译零错**（year_month/local_date/local_date_time/local_time/deprecated_instant/time_zone/utc_offset .cj 各 0 错）。**零新增错误**：残留 5 = R3 已存在的非簇-C 模板（unclosed `(`×1、expected `;`×1、顶层 `extend`×1、`sign` 缺类型×1、emptyIntermediate×1），分布于 date_time_components/formatter/number_consumer/utc_offset_format，与 expect class 无关。
- **验证**: cargo build --release 零 error；全量 single 回归（parser lookahead 改动最高风险——校验 `class Foo\nfun bar` 等无主构造器场景无回归）；抽查 248/249/250（R2 三簇）+ 210/247 通过。
- **意外收益**: `<: Comparable & ToString`（raw Comparable 无泛型实参）在**全量包内**编译通过（corpus 有非泛型 Comparable stub marker），故未触发 supertype-generic-drop；隔离测试因 std 泛型 Comparable 会报 "generic type should be used with type argument"（故 251 测试不带 Comparable 超类型，聚焦分离构造器+存根）。
- **已知残留/风险**: ① 残留 5 错为独立簇（number_consumer 的 `emptyIntermediate`、utc_offset_format/date_time_components/formatter 的 unclosed/expected/extend/sign），非本簇，下轮候选。② expect class 成员全存根——运行时构造后访问即抛，语义上是"占位"（common 侧本无实现，符合预期；平台 actual 未纳入翻译）。③ `is_expect` 仅作用于 render_regular_class；expect object/interface（datetime 中无）未特殊处理，走原逻辑。④ 主构造器 lookahead 回退基于 pos 存取（parser 唯一游标，无 graph/scope 副作用），安全。

### 2026-07-10 — PARSER+RENDER — 2a R4 残留 5 parse 错清零（4 根因）→ 语义层首次翻牌

- **目标**: 2a kotlinx-datetime；R4 基线 output/target_2a_r4 = 5 parse 错，分布 formatter/utc_offset_format/date_time_components。这 5 错仍**遮蔽全包语义分析**（cjc 遇任一 parse 错即中止整包语义阶段），故必须全清才能揭示语义层。逐个回溯 .kt 源构造、修 parser/render 根因（非手补产物）。
- **4 个根因与修复**（全 L1/L2，正交）:
  1. **函数类型在泛型实参内被 `->` 的 `>` 破坏（2 错，formatter.cj）**。Kotlin `List<Pair<T.() -> Boolean, FormatterStructure<T>>>` 渲染成乱码 `ArrayList<((T) -), FormatterStructure<T>>>`。**根因**: `split_top`（按 `<>()` 深度切顶层逗号）把 `->` 箭头里的 `>` 当作闭合括号 → depth 减到负、逗号误判、连累 `map_type` 的 `rfind('>')` 截断出 `((T) -)`。**修复**（parser.rs `split_top`，L1）: 遇 `-` 且下一字符 `>` 时整体透传 `->`、不动 depth。
  2. **局部扩展函数被渲染成嵌套 `extend`（1 错，utc_offset_format.cj:isoOffset）**。Kotlin 在函数体内声明 `fun DateTimeFormatBuilder.WithUtcOffset.appendIsoOffsetWithoutZOnZero() {...}`（合法局部扩展函数）→ 渲染成非法的嵌套 `extend WithUtcOffset {...}`（仓颉禁止函数体内 `extend`）。**修复**（render.rs `render_block_inner`，L2）: 块内语句若为带 receiver_type 的 Func，改渲染为**普通嵌套 func**（去掉 extend 包裹与接收者形参）——探针证实仓颉嵌套 func 能经外层方法的 `this` 解析接收者成员（`offsetHours()` 等），语义等价。
  3. **getter-only 属性丢 getter → 无类型无初始化字段（1 错，date_time_components.cj）**。Kotlin `override val emptyIntermediate get() = expr`（无 backing field）→ `skip_property_accessors` 直接丢弃 getter，产出 `let emptyIntermediate`（无类型无初始化）解析崩溃。**修复**（parser.rs `parse_var_decl` + 新增 `try_capture_getter_init`，L1）: 无初始化器时捕获 getter 的 `= expr`（或 `{block}` 包成 IIFE）作为字段初始化 → `let x = expr`（仓颉无纯 getter 计算属性简写，退化为字段；datetime 此类 getter 多返回常量对象，语义等价）。
  4. **匿名对象 `object : Iface {...}` 渲染成裸 `object` + 无类型字段（1 错，utc_offset_format.cj:OffsetFields.sign）**。Kotlin `val sign = object : FieldSign<...> {...}` → `parse_object_expr` 丢弃对象体、返回 `Raw("object")`（仓颉非法表达式），且宿主字段 `let sign` 无类型（singleton 拆分字段声明与 init 后 `let sign` 无类型解析崩溃）。**修复**（parser.rs，L2）: `parse_object_expr` 捕获首个超类型（映射后）存入新 parser 字段 `pending_object_type`，返回 throw 存根表达式 `(throw Exception("anonymous object stub"))`（Nothing 类型可赋任意字段）；`parse_var_decl` 在 `val x = <匿名对象>` 且无显式类型时用 `pending_object_type` 给字段补类型。构造时抛存根（占位；仓颉无匿名对象等价物，完整降级=提升为具名类属 L3，本轮只做 make-it-parse 揭示语义层）。
- **层级**: L1×2（split_top、getter capture）+ L2×2（局部扩展函数、匿名对象）；parser.rs + render.rs 两文件。
- **测试**: 252_func_type_in_generics（`List<Pair<(Int)->Boolean, String>>` + destructure + 谓词调用）、253_local_extension_fun（扩展函数内的局部扩展函数）、254_getter_only_prop（有/无类型 getter-only）、255_anon_object_stub（匿名对象构造抛存根→捕获）。四例翻译→cjc 编译→运行→exact-match 全绿。
- **2a 测量（R4 5 → R5）**: 5 parse 错**全清零**（split_top 修复清 formatter 2 错；局部扩展函数清 1；getter capture 清 1；匿名对象清 1）。**语义层首次翻牌 = 1237 errors（全量口径）**。
- **语义层首曝分布（R5 选簇关键输入，top 15 模板）**:
  - `undeclared type name`×258（KSerializer×31/SerialDescriptor×20/Decoder×20/Encoder×20 = kotlinx.serialization 未 stub；DateTimePeriod×12、AssignableField×10、Companion×10、DatePeriod×9）
  - `undeclared identifier`×243（require×39、Directive×35、parse×13、it×9、NoSuchElementException×6、Random×6）
  - `override does not have overridden function in supertype`×103（equals×20、hashCode×20、formatter×13、parser×13）
  - `mismatched types`×85
  - `not a member of class`×68（Object×38、YearMonth×6、Instant×5）
  - `generic type should be used with type argument`×62（supertype 泛型实参丢失簇，如 raw Comparable）
  - `extend member not allowed to shadow`×60（extend Instant×40、minus×20、plus×16）
  - `ambiguous match for function call`×53（plus×33、until×6）
  - `invalid binary operator`×37、`no matching constructor`×32（PropertyAccessor×15、TwoDigitNumber×10）、`used before initialization`×22、`enum pattern not matched`×19、`not a member of interface`×17、`non-static member access by type name`×16、`missing argument`×15
  - 热点文件: instant×25、deprecated_instant×20、year_month_range×14、local_date_range×13、utc_offset_format×12、number_consumer×12、time_zone×11
- **验证**: cargo build --release 零 error；全量 single 回归（split_top/parse_var_decl 改动面广——重点校验）；抽查 251/248/247 + 210。
- **已知残留/风险**: ① 匿名对象为 make-it-parse 存根（构造抛异常），完整解法=提升为具名类（L3，视 R5 是否需要）。② getter-only 退化为字段丢失「每次访问重算」语义 + 抽象属性覆盖关系（datetime 常量 getter 无影响；若后续遇有副作用 getter 需升级为仓颉 prop）。③ R5 语义层 1237 错为独立多簇——最大可攻簇: 序列化类型未 stub（KSerializer 族 ~91，加 stub 库或剪枝 serializer 层）、override-supertype 失配×103、supertype 泛型实参丢失×62、extend-shadow×60。④ split_top 的 `->` 透传仅按字符对，不处理 `- >`（带空格，Kotlin 无此写法）——datetime 无此形，安全。

### 2026-07-10 — RENDER_CALLS — 2a R5① Kotlin 前置条件族 require/check/error 真实语义映射

- **目标**: 2a kotlinx-datetime；R5 语义层 `undeclared identifier 'require'`×39（全语料复用，datetime core/common/src 里 `require(` 用 50 处/17 文件，无 check/error/requireNotNull）。Kotlin stdlib 前置条件函数无仓颉对应、原样输出即 undeclared。
- **修复**（render_calls.rs `render_call` NameRef 分支，L1；展开为真实语义**非 stub**）:
  - `require(cond)` → `if (!(cond)) { throw IllegalArgumentException("Failed requirement.") }`
  - `require(cond) { lazyMsg }` → `if (!(cond)) { throw IllegalArgumentException(<lazyMsg>) }`（新增 helper `extract_lazy_message` 提取 lambda 消息表达式；多语句体退化 IIFE）
  - `check(...)` 同上但 `IllegalStateException` / 默认 `"Check failed."`
  - `error(msg)` → `throw IllegalStateException(msg)`
  - `requireNotNull/checkNotNull(x[, {msg}])` → `(match (x) { case Some(_v) => _v; case None => throw IAE/ISE(msg) })`（表达式位解包，datetime 未用但补全）
  - 三处均加 `!self.is_user_func(original)` 守卫（同 abs/max 约定），避免覆盖用户同名函数。仓颉 `if` 无 else 为 Unit，语句/表达式位皆合法（require 返 Unit）。`IllegalArgumentException`/`IllegalStateException` 为 std.core 真实类型（探针验证 String 构造器 + `.message`）。
- **层级**: L1（render_calls.rs 单文件，纯调用映射）
- **测试**: 256_require_check（require 带/不带 lazy 消息、check 带消息、error；catch 验证异常类型 IAE/ISE 与消息文本）。翻译→cjc 编译→运行→exact-match 全绿（`5/ok/IAE: must be positive, got -1/IAE: Failed requirement./ISE: state broken/ISE: negative not allowed: -5`）。
- **2a 测量**: `require` undeclared ×39 → **0**（全清）。输出形如 `if (!((value.isNone()) || (value >= 0 && value <= 99))) { throw IllegalArgumentException("...") }`。
- **已知残留**: lazyMessage 直接用 lambda body 表达式（datetime 全为 String 插值，无需 `.toString()`）；若后续语料出现非 String 消息需补 `.toString()`。

### 2026-07-10 — SCOPE/PIPELINE — 2a R5② kotlinx.serialization 依赖边界剪枝（translate_2a.py）

- **裁决**: `core/common/src/serializers/`（12 .kt）是 **kotlinx.serialization 集成层**——每个文件实现 `KSerializer<T>`，依赖外部库的 `SerialDescriptor`/`Decoder`/`Encoder`（不在本源码树）。这是**依赖边界**（同 1c/1e 先例：外部库不 stub、不硬翻）。R5 语义层里 KSerializer×31 + SerialDescriptor×20 + Decoder×20 + Encoder×20 = 91 直接 undeclared 全部源自这 12 文件，是评估 datetime core 本身的纯噪声。
- **做法**: 新增 `output/translate_2a.py` 测量管线（`--check`/`--validate` + `-o OUTDIR`，argparse）: 把 `core/common/src` 复制到临时目录 → 剔除 `serializers/` 子目录 → 调**项目模式**翻译（`exe <staged_dir> -o OUT`，自动产 cjpm.toml/main.cj）。剪枝在临时副本上做，绝不改真实源码树；覆盖前备份旧输出（file_safety）。
- **重审条件**（写进脚本头注释）: 当 (a) 仓颉出 serialization 库（有 KSerializer/Decoder/Encoder 对应）可映射，**或** (b) 本管线翻译了 kotlinx.serialization 本身（集成层有真超类型可满足）——则 un-prune 重审。
- **主源文件不受影响**: `LocalDate.kt` 等的 `@Serializable(with=…)` 注解被 parser 跳过（注解丢弃），剪 serializers/ 不破坏它们。**残留（报告不处理）**: 主源 `TimeZone.kt:173/273` 在**非注解位**写了 `kotlinx.serialization.KSerializer<T>` 工厂返回类型 → `time_zone.cj:20/46` 2 处残留 undeclared KSerializer，同属该边界，out of scope。
- **2a 测量（R5 1237 → R6）**: 剪枝 12 文件（55→43 .kt，输出 42 .cj，0 serializer .cj 泄漏）+ require 映射，合计 **1237 → 1070（net -167）**。清零 require×39 + KSerializer 族 ×91 + 12 serializer 文件的全部级联错误。
- **R6 语义层残余 top 簇**（下轮候选）: undeclared identifier×189（Directive×35/parse×12/it×9/NoSuchElementException×6/Random×6）、undeclared type×153（AssignableField×10/Companion×10/DateTimePeriod×8/LongProgression×8/Copyable×6）、override 无 supertype×103（equals×20/hashCode×20/formatter×13/parser×13）、mismatched types×85、not a member of class×68（Object×38）、generic type 缺实参×62、extend-shadow×60（extend Instant×40/minus×20/plus×16）、ambiguous match×53（plus×33）、invalid binary operator×43、no matching ctor×32、used-before-init×22、enum pattern×19。热点文件 instant/deprecated_instant/*_range/utc_offset_format/number_consumer。

### 2026-07-10 — PARSER — 2a R6① 父接口位泛型实参保留（interface/父类型位漏网）

- **目标**: 2a kotlinx-datetime；R6 基线 output/target_2a_r6 = 1070，`generic type should be used with type argument`×62。R4 报告已抓线索: raw `class Truth <: Predicate` 丢 `<Any>`。
- **根因**: 1g R7 修过 **superclass 位**（带 `(...)` 实参的父类）保留 type_args，但**父接口位**（无 `(...)` 的超类型，走 `else` 分支 `interfaces.push(safe_name(&sup_name))`）把捕获到的 type_args 丢弃。`class Instant : Comparable<Instant>` → 裸 `<: Comparable`；`class X : Directive<Target>` → 裸 `<: Directive`。同一 type_args 捕获逻辑，两条渲染分支只有一条用了它。
- **修复**（parser.rs 接口分支，L1）: `interfaces.push(if type_args.is_empty() { name } else { format!("{}<{}>", name, type_args) })`。**例外**: 非泛型 marker 桩接口（`MutableList`/`MutableMap`/`Entry`/`MutableEntry`，stubs.rs 注入为空非泛型接口）不加实参——否则 `<: MutableList<Int>` 与非泛型 marker 撞 arity（首次提交回归了 242/243，加 `is_nongeneric_marker` 排除后修复）。`MutableCollection<E>` 是泛型 marker，不排除。
- **层级**: L1（parser.rs 单点 + marker 排除）
- **测试**: 257_supertype_generic_args（`class : Container<Int>` + `interface Labeled<T> : Container<T>` 接口继承接口带实参）。翻译→cjc→运行 exact-match（42/int）。回归修复 242_mutable_list_marker（`: MutableList<Int>` marker）、243_map_entry_supertype（`: Map.Entry<String,Int>` / `: MutableMap<K,V>`）。
- **2a 测量**: `generic type should be used`×62 → **21**（-41）。级联: 加实参后 cjc 开始检查接口 conformance，新增 `class missing abstract modifier / should implement abstract function`×29（Comparable 的 compareTo、Collection 面等未完全实现——真实语义缺口，raw 类型此前遮蔽），属正交下轮候选。
- **已知残留**: type_args 捕获仅取顶层 Ident（`Base<Map<K,V>>` 退化 `Base<Map>`，R7 已知限制）；残留 21 为嵌套/其他路径（enum/object 父类型位若有）。

### 2026-07-10 — HEURISTICS — 2a R6② override equals/hashCode 通用剥离（Kotlin Any vs 仓颉 Object）

- **目标**: 2a `'override' function 'equals'/'hashCode' does not have an overridden function in supertype`（equals×20 + hashCode×20 + 级联）。跨目标复用: 1g ksoup 亦有 14 处。
- **根因**: Kotlin `Any` 有 equals/hashCode/toString；仓颉 `Object` 无 equals/hashCode。Kotlin `override fun equals/hashCode` 在仓颉无可 override 的超类型成员。
- **修复**（heuristics.rs `override_provably_unmatched` + 3 新 helper，L2）: equals/hashCode 特例——当**无祖先类且无已实现接口定义该方法**时剥 override（保留方法体为普通 `public [open] func`）；有祖先/接口定义则保留（用户类链 `A(定义equals)→B(override)` 场景 B 正确 override A 的 open equals）。新增 `find_class_by_name`（扫全图 Class 节点按基名）、`class_defines_method`、`ancestor_defines_method`（沿父类链查，深度上限 32 防环；外部/stub 父类找不到节点视为未定义——仓颉 Object/stub 均无 equals）。**toString 不动**（仓颉 ToString 接口 override 合法，由既有接口成员集判定）。
- **层级**: L2（heuristics.rs，新增名字→节点查找框架）
- **测试**: 258_equals_hashcode_strip（无父类的 Tag/Wrapper override equals/hashCode → 剥离为普通方法，编译+运行 hello/35/hello/36）。
- **2a 测量**: `override does not have overridden function`×103 → **21**（-82，equals/hashCode 及级联全清；残 21 为 copy×6/createEmpty×3/contains/hasNext/now 等**其它**方法，独立簇）。
- **跨目标 1g 复用测量**: 用 R6 译器重译 ksoup（output/target_1g_r8） vs 旧 R7 二进制产物（target_1g_r7）: `override func equals` 7→**0**、`override func hashCode` 7→**0**（14 处全剥）。**但 1g 全量语义数无法本轮测量**——r8 被 8 个 stub typealias redefinition（`type ByteArray/RegexOption/MatchResult/Regex/Appendable`）阻塞在声明阶段。根因: stubs.rs 逐文件注入这些非泛型 typealias，项目模式装配时 3 文件重复定义撞名（io_source_reader*.cj）。此为 **translate_1g 逐文件-stub 去重与 stubs.rs 注入的交互问题，正交于 R6 ①②**（旧 1g-R7 二进制经 k2cj_stubs.cj 去重为单份；当前二进制内联到文件体，装配未去重）——记 1g 战役下轮候选。
- **已知语义缺口（报告记录）**: equals 剥 override 后，`.equals()` 调用仍被既有规则映射为 `==`，而剥离后的类无 `==` 操作符 → `invalid binary operator '==' on Class-X` 系列（本轮编译错已消 override，但 == 语义未通——属 Option/Equatable 战役，需把 `.equals()`/`==` 统一映射到剥离后的 equals 方法或 @Derive[Equatable]）。
- **② 语义副作用**: 剥离后 equals/hashCode 是普通方法，Kotlin `==`/HashMap 键行为语义上不再走它们——已知缺口，同上。

### 2026-07-10 — PIPELINE — R9① 1g 切项目模式（stub typealias 装配去重，解除测量阻塞）

- **背景**: R6 报告 target_1g_r8 被 8 个 stub typealias redefinition（`type ByteArray/RegexOption/MatchResult/Regex/Appendable` 在 io_source_reader*.cj 重复）阻塞在声明阶段，1g 语义层无法测量。
- **根因**: `translate_1g.py` 用**逐文件模式**翻译（历史上为绕过早期 merge-parser bug），单文件模式（render.rs）把 stdlib stub（含非泛型 typealias）注入进**每个文件体**；多个单文件产物装配成一个包时这些 typealias 重复定义撞名。项目模式（project.rs::collect_stubs）本就把所有 stub 汇入**单份 k2cj_stubs.cj**，无此问题。
- **修复**（output/translate_1g.py，非 Rust）: 逐文件模式的 merge-parser bug 已被 R3-R6 解析器修复（expect class / split_top / object-expr 等）消除——改 translate_1g.py 为**项目模式**（`exe <SRC_dir> -o OUT`，镜像 translate_2a.py），whole-tree 一次翻译，stub 自动去重进 k2cj_stubs.cj 单份。旧逐文件脚本可从 git 历史恢复。
- **验证**: 项目模式重译 ksoup（88 文件，k2cj_stubs.cj 单份，`type ByteArray` 仅 1 处）；8 stub redefinition **清零**，声明阶段解除阻塞。
- **2a/1g 测量**: 1g **1355（旧逐文件 r7 基线，已被 stub-dup 阻塞）→ 1306（项目模式 r9，语义层首次完整暴露）**。兑现 R3-R6 跨目标外溢。残 3 个 redefinition（attributeKey/append，Kotlin 重载折叠，语义级不阻塞）。
- **残留**: 项目模式 vs 逐文件的少数差异（88 vs 87 文件）；逐文件模式若某文件触发 merge bug 可回退（git 有旧脚本）。

### 2026-07-10 — PARSER+RENDER — R9② 成员 import 重限定机制（跨目标：1g 双杀，2a 证伪 Directive）

- **目标**: 1g 簇 D `undeclared identifier`（lowerCase×17/normalize×7/normaliseWhitespace 等）——Kotlin `import pkg.Class.member`（静态/companion 成员导入）后裸用 `member`，翻译器原样跳过 import、裸引用 undeclared。
- **根因**: parser 完全跳过 import 行（`仓颉侧自管导入`），不追踪成员 import。`import com.fleeksoft.ksoup.internal.Normalizer.lowerCase` 后 `lowerCase(x)` → 裸 `lowerCase` undeclared（应为 `Normalizer.lowerCase(x)`）。
- **修复**（node.rs + parser.rs + render.rs + heuristics.rs，L2）:
  1. **node.rs**: `Graph` 加 `member_imports: HashMap<String,String>`（member → 限定类型）。
  2. **parser.rs**: import-skip 时收集点分路径段；`record_member_import` 判定成员 import——路径含 `Companion`（无论成员大小写，如 `X.Companion.MAX`）或末段小写开头（`Normalizer.lowerCase`）→ 记 `member → 最近的大写开头段`（跳过 Companion）。末段大写且无 Companion（可能嵌套类型 `P.C.Inner`）跳过；末段前无大写段（顶层函数 `pkg.sub.func`）跳过。
  3. **render.rs**: NameRef 渲染 `decl=None`（未解析）分支，若 `member_imports` 命中**且非外围类成员**，改写为 `C.member`。
  4. **heuristics.rs**: `enclosing_class_has_member`——向上走父链查 name 是否为外围类的字段/方法/companion 成员/构造参数（本地优先关键）。
- **本地优先修正**（关键 bug）: 首版仅用 `decl=None` 门控，但**类成员的隐式 this 引用 decl 也是 None**（如 TimeBased 的 `nanoseconds` 构造参数）——`import kotlin.time.Duration.Companion.nanoseconds` 存在时，本地 `nanoseconds` 被误改写成 `Duration.nanoseconds`（2a 回归 +17 `not a member of struct`）。加 `enclosing_class_has_member` 门控后修复。
- **层级**: L2（4 文件协同）
- **测试**: 259_member_import（`import X.Companion.CONST` + `import Obj.helper` 裸用 → `X.CONST` / `Obj.helper`，编译+运行 U:hi/42）。
- **跨目标测量**:
  - **1g（双杀，主战果）**: 1306 → **1243（-63）**。lowerCase/normalize/normaliseWhitespace undeclared 全清（Normalizer.lowerCase 改写遍布 evaluator/query_parser/safelist 等）。
  - **2a（证伪）**: 963 → 966（**+3，微负**）。2a 的 `undeclared identifier 'Directive'×35` **经查证不是成员 import**——`Directive` 是 `sealed class Directive`（Unicode.kt:245）含嵌套 `DateBased/TimeBased` 等，`Directive.YearMonthBased.Era` 是**嵌套类型限定引用**（嵌套提升后引用未更新），另一根因（下轮候选，挂 engine 嵌套提升注册表）。2a 少数真成员 import（`Duration.Companion.ZERO/isInfinite`）改写正确，但仓颉 Duration 无这些成员 → 由 undeclared 转为 not-a-member（准确揭示 API 缺口，非改写 bug）。
- **已知残留**: ① 2a Directive 嵌套类型引用（真根因，R10 候选）。② member_imports 全局表按成员名键，跨文件同名成员 import 冲突（罕见，last-wins）。③ 顶层函数 import（`import pkg.func`）不改写（无限定类型），保持原样。

### 2026-07-10 — RENDER — R10 Option 家族①：over-unwrap（null-check-rebound 块内 `!!` 去 getOrThrow）

- **战役**: 1g ksoup Option/nullable 硬簇第一批。R9 基线 output/target_1g_r9 = 1243。四子模式新鲜诊断（防刷审计存证）:
  - **① over-unwrap（getOrThrow 非成员）**: `'getOrThrow' is not a member of class`×15（本轮攻打）
  - **② under-unwrap（Option receiver 成员调用）**: `is not a member of enum 'Option<...>'`×79（Element×21/Node×12/String×8/Attributes×7/Tokeniser×7）
  - **③ 可空相等比较**: `invalid binary operator '=='/'!='`×75 中 49 含 Option（==×58/!=×17）
  - **④ mismatched Option<T> vs T**: 混于 mismatched types×243（类型推断核心，L3，本轮不碰）
  - **选 ① 依据**: 边界最清晰（流敏感状态清除，纯 render 层单点），杠杆/风险比最优——15 处同一机械模式，不触类型推断核心。② ③ 需动可空性推断/相等归一，回归面大，留后批。
- **根因**: Kotlin `if (x != null) { ... x!! ... }` 中 `!=null` 守卫被渲染为 smart-cast 重绑定块 `if (let Some(xValue) <- x) { let x = xValue; ... }`——块内 `x` 已是**非 Option 本地量**。但 `x!!`（ForceUnwrap on NameRef）在 render.rs:593 只查 `is_nullable_expr`（看字段声明类型 `?T` → true）就发 `x.getOrThrow()`，未查是否处于重绑定块。成员访问自动解包路径（render.rs:748）**早已有** `!self.is_null_check_rebound(base)` 门控，但 ForceUnwrap 分支漏了同一门控——两条解包路径只有一条用了 rebound 判定。
- **修复**（render.rs ForceUnwrap NameRef 分支，L1 单点）: `if self.is_nullable_expr(expr) && !self.is_null_check_rebound(expr)`。复用既有 `is_null_check_rebound`（walk-up 找祖先 If 的 `!=null`/`==null` 守卫 + 非重赋值判定）。
- **边界正确性**（生成码核验，test 260）: ① `if(x!=null){x!!}` 守卫块内 → `x.name()`（去 getOrThrow ✓）；② early-return `if(x==null)return; x!!`（守卫块是**兄弟**非祖先，walk-up 不经过 If）→ 保留 `x.getOrThrow()`（`x` 确仍 Option ✓）；③ 无守卫 `b!!` → 保留 `b.getOrThrow()`（✓）。
- **层级**: L1（render.rs 单分支加一个既有 helper 调用）
- **测试**: 260_option_over_unwrap（守卫块 `!!` + early-return `!!` + 无守卫 `!!` 三路 + `==null`/`!=null` 两向；翻译→cjc→运行 exact-match `empty/none/hello/hello/world`）。
- **测量**:
  - **1g（主战果）**: 1243 → **1234（-9）**。`'getOrThrow' is not a member of class`×15 **全清**（attribute×8/node×4/html_tree_builder×3/element×1）；净 -9 因去 getOrThrow 后 6 处下游错误显形（此前该行 getOrThrow 报错遮蔽了后续 typecheck）: `invalid binary operator`+1、`no matching function for operator '()'`+2 等，属诚实新表面非回归。`not a member of class` 123→108（-15）。
  - **2a（外溢）**: 966 → **963（-3）**，无回归。2a 残 5 处 `getOrThrow' is not a member of enum 'DayOfWeek'` 是**另一子模式**（over-unwrap on 非 Option 枚举值，非 null-check-rebound 场景），本修复正确未触及，独立候选。
- **回归**: 单文件 251/251→252/252（含新 260）全绿三阶段（译/编/运行）。
- **残留（下批候选，基于 R10 新分布决策）**: ② under-unwrap 79（最大剩余 Option 簇，需动 `x?.foo()`/可空字段成员调用的解包插入或 Option receiver 判定）；③ ==/!= 可空归一 49（两侧 Option 对齐或生成解包比较）；2a DayOfWeek 枚举 over-unwrap 5（非 null-check 的 getOrThrow-on-enum，独立机制）。

### 2026-07-10 — RENDER+HEURISTICS — auto R11 Option 家族②：under-unwrap（可空 receiver 成员调用解包）

- **战役**: auto R11，Option/nullable 第二批 under-unwrap。基线 output/target_1g_r10 = 1234。症状 `'foo' is not a member of enum 'Option<X>'`×79（Element×21/Node×12/String×8/Tokeniser×7/Attributes×7…）——可空 receiver 上直接调成员未解包。
- **分桶诊断**（79 例按 receiver 形态回溯 .kt）:
  - **A 循环游走局部**（~11）: `var parent = parent()` + `while(parent!=null){ parent=parent.parent() }`——局部由方法返回 `?T` 初始化, 循环内重赋值。`is_null_check_rebound` 因 block_assigns 返 false（正确，无 rebind），但 receiver 判不出可空。
  - **B `&&` 短路守卫**（~10）: `(x.isSome()) && x.foo()`——源 `x!=null && x.foo()`，第二 operand 需解包（短路保证安全）。
  - **C 可空字段/继承字段 receiver**（~15）: `tokeniser.transition()`（tokeniser 是**基类 TreeBuilder 的成员 var** `?Tokeniser`）、`_stack.size`。
  - **D 非 NameRef receiver**（cast/index/双 Option/assign-target，~15）: `(x as Element).foo()`、`keys[i].toAsciiLower()`、`??Element`、`clone.field=...`。
- **根因（两处覆盖缺口）**:
  1. **方法调用路径不解包**: 成员**字段读** `x.field` 走 render.rs 成员访问路径（748 行**已有** getOrThrow 自动解包 + `is_null_check_rebound` 门控，R10 就在其旁补的），但**方法调用** `x.foo()` 走 render_calls.rs::render_member_call → `self.atom(base)`，**从不解包**——两条 receiver 渲染路径只有字段读那条接了解包。
  2. **局部可空性推断缺口**: `is_nullable_expr` → `expr_type_name` 的 VarDecl-init 分支只处理 `Call{NameRef}`（构造器）/NameRef/CollLit 初值，不递归 `Call{Member}`（方法返回 `?T`）/`Member`（字段读）初值 → 循环游走局部/字段派生局部判不出可空。
  3. **`field_type_by_name` 只查构造参数**: 不含类体 member `var`/`let` 字段 → 继承自基类的 `tokeniser`/`_stack` 等裸 `this.field` receiver 判不出可空。
- **修复（三小步，逐步回归）**:
  - **Step1**（render_calls.rs，L1）: 新增 `render_call_recv(base, safe)`——`!safe && is_nullable_expr(base) && !is_null_check_rebound(base)` 时插 `.getOrThrow()`，与 748 行语义一致；render_member_call 用它替换 `atom(base)`，签名加 `safe`（`?.` 安全调用不解包，保 None 短路；rebind 不解包，防 R10 over-unwrap 回归）。单独测：79→78（-1，仅补了基础设施，多数 receiver 判不出可空）。
  - **Step2**（heuristics.rs is_nullable_expr，narrow）: 局部无声明类型时, 由 `Call`/`Member` 初值递归推断可空（`expr_type_name(Call)` 已能取方法返回类型；`is_nullable_expr(Member)` 已能查字段类型）；仅对 Call/Member 初值递归（不含 NameRef，避免 `var x=x` 自引用环）。**不改** expr_type_name 全局（避免污染其它 heuristic）。79→51（-28）。
  - **Step3**（heuristics.rs field_type_by_name，扩展既有路径）: 构造参数无命中时, 回退扫类体 member `VarDecl`（带显式类型）——覆盖继承自基类的字段。79→40（-11）。
- **层级**: L1（render 单点）+ L2（两个既有 helper 扩展，无新机制）
- **测试**: 261_option_under_unwrap（循环游走 method+field 解包 / `&&` 短路解包 / if-let rebind 非回归 / `?.` 安全调用非回归；翻译→cjc→运行 exact-match 8 行 `0/none/empty/nil/3/one/c1/c1`）。
- **测量**:
  - **1g**: 1234 → **1203（-31）**。under-unwrap `not a member of enum 'Option'` **79→40（-39）**。级联（诚实新表面, 均 <阈值）: not-a-member-of-class 108→114（+6, 解包后 receiver 落到具体类, 暴露该类真实 member-not-found）、mismatched +1。**无簇上升>20**。
  - **2a**（已标暂停, 仅记录）: 963 → **963（0）** 无外溢无回归（2a under-unwrap 本就仅 3）。
- **回归**: 单文件 252/252→**253/253** 全绿三阶段（含新 261）。Step3 是最高风险改动（field_type_by_name 跨类按名返首个匹配, HashMap 序不定有歧义风险）——回归全绿判定安全, 保留。
- **L3 残留桶清单（R12 候选，40 例，均需更深类型流或非 NameRef receiver 支持, 本批按约定跳过）**:
  - **桶 D-cast**: `(x as Element).foo()` cast 表达式 receiver（node.cj elementIs/invalidateChildren×2、element.cj childElementsList、leaf_node value）——需 cast 结果可空性推断。
  - **桶 D-index**: `arr[i].toAsciiLower()` 下标 receiver（attributes.cj toAsciiLower×4、tokeniser）——需下标元素类型可空推断。
  - **桶 D-assign**: `clone.field = ...` 赋值目标成员（document outputSettings/attributes、element childNodes×2/attributes×2、tag_set tagName/options）——赋值目标路径不走解包。
  - **桶 D-double**: `??Element` 双 Option（element.cj:920/923 el.tag/el.parent）。
  - **桶 C-ambig**: `let a = obj.field` Member-init 局部, field_type_by_name 跨类同名歧义（html_tree_builder attributes isEmpty/deduplicate、token attributes.size×2）——需按 receiver 静态类精确定位字段（enclosing-class + 继承链解析）。
  - **桶 misc**: tokeniser.cj name/hasAttributes/retrieveNormalName（lastStartTag/EndTag 局部）、tree_builder/html_tree_builder `_stack.remove/clear` 部分残留。

### 2026-07-10 — RENDER+HEURISTICS — auto R12 Option 家族③：==/!= 可空/引用相等归一

- **战役**: auto R12，Option/nullable 第三批「相等归一」。基线 output/target_1g_r11 = 1203。症状 `invalid binary operator '=='/'!='`×76（==×58/!=×18，其中 52 含 Option/This）——仓颉引用类**无默认 `==`**，且 `Option<T>` 与 `T` 混比类型不匹配。
- **探针先行**（cjc 1.0.5 实证，防臆断）:
  - `refEq(a,b)` 对类实例做引用相等（子类型 upcast 自动）；`Option<Int64>==Option<Int64>` 成立（Int64 Equatable），但 `Option<Node>==Option<Node>` 失败（Node 非 Equatable）。
  - 非泛型 `?Object` 辅助**不可行**：Option 不变（`Option<Node>` ✗→ `?Object`）；裸类值可 upcast。
  - **双泛型** `func __k2cjRefEq2<A,B>(a:?A,b:?B): Bool where A<:Object,B<:Object`（match Some/Some→refEq, None/None→true, _→false）**全通**：裸值自动装箱、Option 透传、A/B 独立消解**跨子类型**（无需公共超类推断）。这是关键设计——单泛型 `<T>` 对 `Node vs Element` 会推断失败。
- **分桶归一策略**（render.rs::render_eq_normalized，两侧均非 None 字面量时触发）:
  - **桶 A（Ref，主战果）**: 两侧类别均为引用（普通类/`Object`/`this`）→ `__k2cjRefEq2(a,b)`（`==`）/ `!__k2cjRefEq2(a,b)`（`!=`）。覆盖 `Option<Cls> vs Cls`、`Option<Cls> vs Option<Cls>`、`Cls vs Cls`、`this === other`（词法把 `===` 退化为 `==`，引用语义正确）。
  - **桶 B（Equatable）**: 两侧均值类型（String/Int64/枚举/value class）且**恰一侧可空** → 裸值一侧包 `Some(...)`，令 `Option<T>==Option<T>` 成立。
  - **桶 C（结构 equals 派发）**: **延后 R13**——`equals(other:?Object)` 体内 `when(other){is T}` / `other as T` **无法匹配调用点自动装箱的 `Some(arg)`**（arg 被包成 `Option<Object>` 而非 T），派发会静默返回错误结果（探针实测 `p.equals(q)` 结构相等误返 false）。故同类含 equals 的比较本轮**一律走桶 A 引用相等**（能编译、引用语义），结构相等闭环 = R13 首要任务。`class_has_equals`/`same_equals_class` 已实现并 `#[allow(dead_code)]` 保留待 R13。
  - `x==null`/`x!=null` 仍映 `isNone()`/`isSome()`（既有，未动）。
- **类别判定**（heuristics.rs，保守「判不出不动」）: `EqCat{Equatable,Ref,Unknown}` + `eq_type_category(base)`（内建值/枚举/value class→Equatable；普通类/Object→Ref；否则 Unknown）+ `classify_eq_operand`（`this`→按外围类；Member 字段→`member_field_type`；`let x=recv.method()` 局部→由 Call/Member 初值返回类型推断——**局部于 classify，不污染全局 expr_type_name**）。防误改护栏：value class（struct，@Derive[Equatable]）与带参枚举（含手写 `==`）归 Equatable 不走 refEq，避免改坏当前可编译的结构相等。
- **实现关键坑**（首版 net 仅 -5，修正后 -53）: `__k2cjRefEq2` 是**泛型顶层函数**，按 RuneSlice 那样每文件私有注入会「**overload conflicts**」（16 文件重复定义，泛型模板不同于具体签名的 RuneSlice 可容忍）→ 改为**整包写一次**独立文件 `k2cj_refeq.cj`（project.rs），单文件模式（render.rs）仍每文件注入（仅一份不冲突）。
- **层级**: L2（render.rs 相等归一新分支 + heuristics.rs 分类/成员类型 helper + project.rs 单份辅助注入）
- **测试**: 262_option_equality（桶 A 引用身份 Option/裸/this===、桶 B Some 包裹、含 equals 类走引用、None==None、isNone/isSome；翻译→cjc→运行 exact-match 18 行）。
- **测量**:
  - **1g（主战果）**: 1203 → **1150（-53）**。eq `==`/`!=` **76→22（-54）**，`refEq2` 注入 49 调用点、**0 自致错误**。净 -53≈eq 减量（级联近零）。
  - **2a（外溢，已标暂停仅记录）**: 963 → **964（+1）**。2a eq 5→2（-3），refEq2 17 调用 0 自致错误；+1 系 -3 eq 修复**下游级联显形**（诚实新表面非 refEq2 缺陷），远低于 +20 停机阈值。
- **回归**: 单文件 253/253→**254/254** 全绿三阶段（含新 262）。
- **残留（22 例，均 render 期类型判不出，按「宁残留勿误改」保守留）**:
  - **javaClass 退化**（~8）: `this.javaClass != other.javaClass` 中 `.javaClass` 被 render 丢弃→lhs 是 Member 节点判 Unknown（equals 样板里的 `This != Option<Object>`×5 等）；**既有误译**（类型反射比较），独立候选。
  - **集合下标**（~6）: `el == formattingElements[i]` / `children[i] != x[i]`——下标元素类型未推断。
  - **迭代器/未知返回局部**（~2）: `let node = it.next()`（next 返回类型不在 func_index）。
  - **R11 under-unwrap 函数值**（~3）: `Int64 != () -> Int64`（方法未加 `()` 调用）——非本桶，R11 残留。
  - **泛型参**（~1）: `Generics-E == Class-Element`。
- **R13 首要**: 桶 C 结构相等闭环——需解决 `equals(?Object)` + 调用点 Some 装箱的 when-is/as 匹配缺口（或改 equals 派发为不装箱的直调）。`class_has_equals`/`same_equals_class` 已备。

### 2026-07-10 — RENDER+HEURISTICS — auto R13 Option 家族④：== 语义闭环（桶 C 结构 equals 派发）

- **战役**: auto R13，== 语义闭环（审计强制项——R8 剥离 equals/hashCode 的 -96 不闭环将追溯重计）。基线 output/target_1g_r12 = 1150。
- **探针先行**（cjc 1.0.5 实证，两方案均通）:
  - **A（equals 体先解包）**: `match(other){case Some(o) => o is T ...}`——`o is T`（o: Object 持 T）成立✓，`(o as T).getOrThrow()`→T✓。且 `is`/`as` **直接**作用在 `?Object` 上**恒 false/得 Option<T>**（实证 `other is T` on ?Object 恒 false）——必须先解包。
  - **B（operator ==+Equatable<T>）**: `operator func ==(that:T){equals(that)}` + `<:Equatable<T>`——直接 `T==T`✓、`Option<T>==Option<T>`✓（Option Equatable）、与 refEq2 共存✓。
  - **选 A**：修 equals 体（B 也依赖体正确），调用点走桶 C 空安全 `.equals()` 派发（`equals(?Object)` 自动装箱裸值）——无需改类继承/加 operator，回归面更小。
- **根因**: `equals(other: ?Object)` 体内三类原语对 `?Object` 失效——① `other is T`（IsCheck）恒 false；② `other as T`（TypeCast）得 `Option<T>`（且 Option<Object> 不能直接 as），赋给 `: T` 局部即类型错；③ `this::class != other::class`（`::class` 反射被降为 base → `this != other`，This vs ?Object）。
- **修复（render.rs 三处 + heuristics 重构）**:
  1. **IsCheck 可空感知**: `x is T`（x 可空且非 rebind）→ `(x.isSome() && x.getOrThrow() is T)`；`!is` → `(x.isNone() || !(x.getOrThrow() is T))`。
  2. **TypeCast 可空感知**（非 safe `as`）: `x as T`（x 可空）→ `(x.getOrThrow() as T).getOrThrow()`（解包→向下转型→再解包，对齐 Kotlin 非空 as 得非空 T；空则抛错≈CCE）。
  3. **`::class` 反射比较**（render_class_reflection_eq）: 两侧均 `::class`/`javaClass` 成员且一侧 `this` → `(other is EnclosingClass)`（`==`）/取反（`!=`）（仓颉无 getClass，以外围类 `is` 近似，对 jsoup final DOM 类精确）。
  4. **桶 C 空安全派发**（render_eq_normalized + heuristics same_equals_class 重写返回 `(类名,ln,rn)`）: 两侧同一含 equals 引用类 → 按可空组合生成空安全结构相等（都非空 `a.equals(b)`；一空 `x.isSome() && ...`；都空 `(都 None)||(都 Some && 结构)`）。任一侧 `this` 不派发（`===` 引用语义 + 防 equals 体自递归）。
  5. **heuristics 重构**: 抽 `resolve_eq_type(id)→(基类型名,可空)`（综合 expr_type_name/成员字段/Call-init 局部三路径），classify_eq_operand 与 same_equals_class 共享。
- **层级**: L2（render.rs 三渲染点 + heuristics 类型解析重构）
- **测试**: 263_equals_dispatch（**语义闭环证明**，含运行时断言）——结构相等（同值异实例 `Point(1,2)==Point(1,2)` → true）/ 非相等 false / null 组合（都空真、一空假、opt-vs-裸真）/ 无 equals 类 `Ref` 走 refEq 身份（异实例 false、同实例 true）互不干扰；翻译→cjc→运行 exact-match 14 行全绿。
- **测量**（**本轮考核=语义闭环非错误数**）:
  - **1g**: 1150 → **1135（-15）**。eq `==`/`!=` 22→18。equals 派发桶由引用语义**升级为结构语义**（如 `a.attributes().equals(b.attributes())` 现为结构比较）——语义升级 + 编译中性；-15 来自 IsCheck/TypeCast/`::class` 修复令 equals 体编译。
  - **2a**（外溢，仅记录）: 964 → **967（+3）**。级联/新表面（如 `Rune != UInt8`×1），refEq2/equals-派发 0 自致错误，全局 is/as 改动在 2a 几乎未触发。
- **回归**: 单文件 254→**255/255** 全绿三阶段（含新 263）。**262 改造**：其 Box 原含 `when(is)`-form equals（TypePat-on-Option，本轮 IsCheck 修复不覆盖 when 臂），R13 派发到该 broken equals 致 262 回归 → 将 Box 改为**纯引用类**（无 equals），归位为 refEq2 桶回归守卫（262 期望不变，仍绿）。
- **== 语义闭环进度：桶 C 部分完成 5/8**:
  - **已闭环（5）**: attribute / attributes / safelist / tag_set（显式 `let x = other as T` 绑定，TypeCast 修复直达）+ node（refEq2 身份——jsoup Node.equals 本即 `this === o` 身份，语义正确）。
  - **残留（3，下轮候选）**: tag / nodes / identity_hash_map——`other as T` **裸语句 smart-cast** 后 `other.member`（tag `other.options`、id_map `other.value`）/ `other[i]`（nodes 集合下标）仍作用在 `Object`（未向下转型）。根因 = **flow-sensitive smart-cast 未跟踪**（`if(other is T)`/`other as T` 后 `other` 应被视为 T）——独立深层特性，非本桶原语，留下轮（同时可闭 262-Box 的 when-is 场景）。
- **审计**: R8 剥离 equals/hashCode 的 -96，结构语义对 **5/8** 类闭环 + 机制经 263 运行时证明；3 类残留待 smart-cast 跟踪。

### 2026-07-10 — RENDER — auto R15 簇 E：Kotlin null-aware 扩展 `isNullOrEmpty()` 映射（形参可空性证伪→真根因）

- **战役**: auto R15（终轮），1g 簇 E「形参过度可空化」。基线 output/target_1g_r14 = 1136（本机 error 行计 1146）。
- **诊断证伪（以新鲜诊断为准，推翻 R6 存证前提）**: R6 断言 `Validate.notEmpty(string: String)` Kotlin 原型**非空**、启发式过度可空化把形参升 `?`。核查 Kotlin 源 `helper/Validate.kt`——`fun notEmpty(string: String?)` 形参**本就可空**，仓颉侧 `?String` **翻译正确**，不存在过度可空化。探针实证 cjc 1.0.5：`String → ?String` 在函数调用实参处**隐式协变**（`V.notEmpty(nonNullStr)` 直通），两 overload 并存亦不歧义。故「44 个非空实参不匹配可空形参」的因果**不成立**。
- **真根因（级联，非可空性）**: `Validate.notEmpty`/`notEmptyParam` 体内 `string.isNullOrEmpty()`（Kotlin `CharSequence?.isNullOrEmpty()` 空安全扩展）被翻译成 `string.getOrThrow().isNullOrEmpty()`——**两处错**：① `isNullOrEmpty` 无映射被透传，非仓颉 String 成员；② 可空接收者被 `render_call_recv` 插 `.getOrThrow()`（在 null 时抛异常，正好抹掉扩展存在意义的 null 分支）。宿主函数体编译失败（`isNullOrEmpty is not a member of struct String`×7）→ 其 decl 被污染 → **44 个调用点级联** `no matching function declaration for function call notEmpty`。escape×3/selectNodes×2 等经查为**各自独立**的宿主体编译失败级联（不同函数，非同根），本轮不动。
- **修复（render_calls.rs::render_member_call 新增 arm）**: `x.isNullOrEmpty()`（无参）→ 用**原始未解包**接收者（绝不插 getOrThrow）：可空且非 rebind 且非 `?.` → `((x?.isEmpty()) ?? true)`（None 短路成 true、Some 走 .isEmpty()，对 `CharSequence?` 与 `Collection?` 同构）；否则（已 smart-cast 非空/本就非空）→ `x.isEmpty()`。探针证实 `?.` 不能作用于非 Option（故按可空性分支）。仅映 `isNullOrEmpty`（实测唯一需求，`isNullOrBlank` 语料 0 命中，按 stub 最小化铁律不预加）。
- **层级**: L1（单文件 render_calls.rs 单 arm）。
- **测试**: 新增 264_param_nullability——非空形参契约 + null-aware 扩展闭环：`notEmpty(s: String?)` 用 isNullOrEmpty；非空实参直通、`""` 空、null/Some、以及 `List<Int>?` 集合变体；翻译→cjc→运行 exact-match 6 行全绿（含运行时语义断言 true/false/false/true/true/false）。
- **测量**:
  - **1g（主战果）**: 1146 → **1087（-59 error 行）**。`notEmpty` no-matching **44→0**、`isNullOrEmpty is not a member` **7→0**；错误类型分布 diff **零新增/零上升**（纯下降，无新表面），-59 = 44 簇 + 7 体错 + 8 下游级联消解。
  - **2a（外溢）**: 967 → **964（-3，改善）**。datetime 侧 isNullOrEmpty 少量命中，无回归（远低于 +10 阈值）。
- **回归**: 单文件 255/255 → **256/256** 全绿三阶段（翻译/编译/运行，含新 264）。
- **分账**: 无新表面需适配——形参可空性**未收紧**（诊断证伪，`?String` 本就正确），故不存在「调用点真传 Option 被收紧误伤」的场景；纯属扩展方法映射补全 + 接收者解包纠偏。

### 2026-07-10 — PARSER — auto R1/20 簇 A：enum-entry-body 截断阶段①（68/24 条目全保留）

- **战役**: auto R1/20（1g 战役轮 R16），簇 A「enum-body 截断」。基线 output/target_1g_r15 = 1084（本机 error 行计）。
- **证实（真根因）**: Kotlin enum 条目带匿名类体（`Data { override fun read(t,r){...} }`，即每条目 override 抽象方法）时，parser 条目循环（parse_enum）读完条目名后只处理 `(entry_args)` 与 `,`，条目体 `{` 两者皆不匹配 → **循环在首个条目后 break**。TokeniserState 68 条目仅存 Data、HtmlTreeBuilderState 24 条目仅存 Initial，其余全丢 → 引用处 "not a member of enum TokeniserState"×13 + 大量 tokeniser 级联。
- **二次暴露的致命错（本轮同修）**: 阶段①令 HtmlTreeBuilderState 首次被完整解析后，`;` 后成员区的 token-by-token bump 走进嵌套 `object Constants { ... }` 体，在其**内层 `}`** 误判为 enum 结束 → 把 enum 自身 `}` 与 `public companion object {...}` 泄漏到顶层，`expected declaration, found 'companion'` 致命 parse 错（1 error 即中断整包）。
- **修复（parser.rs parse_enum，阶段①·L2，两处）**:
  1. 条目循环：`entries.push` 后 `skip_newlines`，若 `is_sym("{")` 则 `skip_balanced_braces()?` 跳过条目体、保留条目名，再走既有 `,` 检查。条目体的 override 方法本轮**丢弃**（enum_members 本就未存入 Kind::Enum，见既有注释）。
  2. `;` 后成员区 else 分支：`is_sym("{")` → `skip_balanced_braces` 平衡跳过（嵌套 object/block 体），否则才 `bump()`。防内层 `}` 提前终结成员环。
- **层级**: L2（parser.rs 单函数两点，纯 parse 侧，不涉 render）。
- **测试**: 新增 265_enum_entry_body——条目体 + `;` + 抽象方法 + 嵌套 `object Constants` + `companion object` 全 shape（复刻 TokeniserState/HtmlTreeBuilderState 双 bug）；断言 4 条目全存活（First/Third/Last 引用 + == 判定）+ 无 companion 泄漏；翻译→cjc→运行 exact-match 5 行全绿。
- **测量**:
  - **1g（主战果）**: 1084 → **1072（-12）**。TokeniserState not-member 13→8、"is not a member of enum" 簇 49→43、undeclared id 144→136；68+24 条目结构全对，零新表面。残 TokeniserState×8 = companion 常量（nullChar/eof）+ read 方法访问 → 阶段②。
  - **2a（外溢，仅记录）**: 重译 target_2a_r16 = **964**（≈基线 963/964，parser enum 改动对 2a 中性，无回归）。
- **回归**: 单文件 256→**257/257** + 项目 **36/36** 全绿三阶段（含新 265）。
- **阶段②（探针证可行，落 R17 候选，本轮未实现）**: 仓颉 enum 可挂成员 func 用 `match(this)` 集中分派——探针 output/probe/enum_member_probe/probe.cj 经 cjc 1.0.5 编译+运行通过（`St.TagOpen.read(10)`→12、toString→TagOpen）。**未实现原因**: 完整阶段②需(1)解析期捕获每条目体(2)渲染抽象方法为 match(this) 分派(3)渲染 companion（常量 + ~15 私有 helper 如 readCharRef）；条目体重度引用 companion 作用域符号，若不同步渲染 companion，分派体无法编译，部分实现极可能净负 → 整体排 R17。
- **R17 候选（基于 post 聚类）**:
  1. **簇 A 阶段②**（enum 成员 func + match(this) 分派 + companion 渲染）——机制已探针验证，需 parse 捕获 + render + companion 三件套。
  2. **FilterResult 嵌套 enum-in-interface 未提升**（×16 = undeclared id×12 + type×4）——`NodeFilter` interface 内 `enum class FilterResult` 既不在 interface 也无顶层输出，疑 renderer 只从 class 路径提升嵌套 enum（line 1599/1833），interface 路径缺提升。与簇 A 同为「结构截断」族，根因在 render 提升侧，L2 可能较廉。
  3. mismatched types×241 / undeclared identifier×136（长尾语义层）。

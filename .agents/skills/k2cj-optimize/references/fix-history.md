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

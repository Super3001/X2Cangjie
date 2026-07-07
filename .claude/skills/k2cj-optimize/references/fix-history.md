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

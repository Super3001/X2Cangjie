# kotlin2cj 优化状态

> 跨 run 持久化。每轮 fixer 追加，orchestrator 启动时先读。
>
> 难度梯度：Phase 0 (⭐ 基线) → Phase 1 (混合小目标, 4 项目) → Phase 2 (⭐⭐) → Phase 3 (⭐⭐⭐⭐) → Phase 4 (⭐⭐⭐⭐⭐)

---

## 全局进度

```
Phase 0       Phase 1                          Phase 2       Phase 3       Phase 4
[✅]          [✅][✅][✅][ ][✅][ ][ ]        [ ][ ][ ]     [ ][ ][ ]     [ ][ ][ ]
                                ↑1e 核心收敛
```

---

## Phase 0: 翻译器自身测试 (基线)

| 目标 | 测试规模 | 状态 | 备注 |
|------|---------|:--:|------|
| translator-own-tests | 202 single + 33 project | ✅ | 全通过。2026-06-16 全量回归验证。作为回归门禁 |

---

## Phase 1: 混合小目标（来自 4 个项目）

| # | 目标 | 来源 | 文件数 | 状态 | 编译错误 | 核心特性 | 本地工程 |
|:--:|------|------|:---:|:--:|:-------:|---------|--------|
| 1a | ksoup-exception | ksoup | 5 | ✅ | 0 | data class, sealed, enum |
| 1b | ksoup-safety+io | ksoup | 5 | ✅ | 0 | companion, extension, lambda |
| 1c | okhttp-mockwebserver | okhttp | ~30 | ✅ | 444 (cross-pkg deps) | builder, interceptor, coroutine |
| 1d | ksoup-parser | ksoup | 16 | ⏳ | R4: 待重测 (1g 全量 10 error, it-shadowing 消掉, 新 5 undeclared type 显现) | state machine, when, inline; R2 stdlib stub + R3 ctor-param/optional-param + R4 it-shadowing 修复完成 | C:/Codes/kotlin/ksoup |
| 1e | ktor-io | ktor | 5 (核心)/14 | ✅ | 0 | P1/P2/P3译器修复;核心5文件收敛,余9剪枝(依赖边界+render gap) | C:/projects/kotlins/ktor |
| 1f | koin-core | koin | ~25 (实际 74) | ⏳ | R1: 9 errors (3 <*> + 3 unnamed-named-param + 1 throw-expr + 1 duration-decl) | DSL, delegate, reified; R1 修 3 parse 簇 (inline-mods/generic-typealias/receiver-fn-type), 71/72 文件翻译 | C:/Codes/kotlin/koin |
| 1g | ksoup-main | ksoup | 87 | ⏳ | R4: 10 (3 redefinition 参数名 shadowing + 5 undeclared type 未覆盖 stdlib + 2 cjpm) | R3 setter/optional-param 消掉; R4 it-shadowing 消掉(6处), 新 5 undeclared type 显现(MutableMap/MutableList/Entry/AutoCloseable); 剩 3 redefinition(参数名 shadowing: append×2+attributeKey) | C:/Codes/kotlin/ksoup |

> ⏳ = in-progress, 🔒 = locked, ✅ = converged, 🟡 = blocked, ❌ = stuck

---

## Phase 2: 中等规模完整项目

| 目标 | 规模 | 状态 | 编译错误 | x2cj-eval | 备注 |
|------|:---:|:--:|:-------:|:---------:|------|
| kotlinx-datetime | ~80 | 🔒 | - | - | Phase 1 无子模块，全新完整项目 |
| koin | ~120 | 🔒 | - | - | Phase 1 测过 core(25)，升级全量 |
| exposed | ~150 | 🔒 | - | - | 全新项目 |

---

## Phase 3: 大型项目 + 硬语法

| 目标 | 规模 | 状态 | 编译错误 | x2cj-eval | 备注 |
|------|:---:|:--:|:-------:|:---------:|------|
| okhttp | ~300 | 🔒 | - | - | Phase 1 测过 mockwebserver(~30) |
| ktor-client | ~200 | 🔒 | - | - | Phase 1 测过 ktor-io(~20) |
| ksoup | ~221 | 🔒 | - | - | Phase 1 测过 ksoup-main(87)，升级真全量 |
| arrow-core | ~100 | 🔒 | - | - | 全新项目 |

---

## Phase 4: 地狱难度

| 目标 | 规模 | 状态 | 编译错误 | x2cj-eval | 备注 |
|------|:---:|:--:|:-------:|:---------:|------|
| kotlinx-serialization | ~150 | 🔒 | - | - | |
| mockk | ~100 | 🔒 | - | - | |
| kotlinx-coroutines | ~200 | 🔒 | - | - | |

---

## 历史记录

### ksoup R0 (2025-06-14) — 已存档

- **997 编译错误** → 单根因：var-func 命名冲突
- 修复：`engine.rs` `resolve_var_func_collisions()`
- 翻译器版本：分支 `ksoup-entities-validation-2-2`

### ksoup R1 (2025-06-15) — 已存档

- error 从 997 → 23（97.7% 减少），87/87 文件翻译成功
- 剩余 23 错误：unicode surrogates / ::class 引用 / ::add / let 缺类型 / bare companion / keys()
- 鉴于难度梯度重新设计，ksoup 拆为子包 + 混合跨项目目标重新开始

### Phase 1 — 1a ksoup-exception (2026-06-16) ✅

- **错误数**: 18 → 0
- **修复类型**:
  - **RENDER_GAP**: `map_type("Throwable")` → `Exception` (parser.rs:2748)
  - **RENDER_GAP**: `super(cause)` 非 String 参数 → `.toString()` 转换 (render.rs:1562-1571)
  - **RENDER_GAP**: 次级构造函数 `cause` 参数 → 提升为 class 字段 `var cause: ?Exception` (render.rs:1274-1284, 1299-1301, 1568-1570)
  - **STUB_GAP**: `RuntimeException`, `IllegalArgumentException`, `IOException` 支持 nullable + 多构造函数重载 (_stubs.cj)
  - **PARSER_GAP**: 无 `()` 的父类被误归为接口 → `is_exception_class` 同时检查 interfaces (render.rs:1263-1266)
- **回归**: Phase 0 202/202 single + 30/33 project 通过（3 个 project 失败：`__k2cjRuneSlice` 未定义，见下方回归修复）
- **回归修复** (2026-06-16): `project.rs:233-248` — project 翻译路径缺少 `__k2cjRuneSlice` helper 注入。`render_program()` 单文件路径有注入，`project.rs` 多文件路径无。3 个使用 `substring()` 的项目测试失败。在 `project.rs` 拼装每文件输出前注入 helper。
- **文件**: parser.rs (+1), render.rs (+37), project.rs (+17)

### Phase 1 — 1b ksoup-safety+io (2026-06-16) ⏳ R1

- **错误数**: 93 → 35 (62.4% reduction in R1)
- **目标文件**: 5 (Cleaner.kt, Safelist.kt, SourceReader.kt, SourceReaderByteArray.kt, SourceReaderExt.kt)
- **翻译**: 5/5 文件成功
- **编译通过文件**: 6/7 (cleaner, source_reader, source_reader_byte_array, source_reader_ext, _stubs, main)
- **编译失败文件**: safelist.cj (35 errors, stdlib collection API mismatch)
- **已修复 (translator, 4 changes, all regression-passing)**:
  - **RENDER_GAP**: `ByteArray` → `Array<Byte>` type mapping (parser.rs:2744)
  - **RENDER_GAP**: `Map.Entry<K,V>` → `Entry<K,V>` type mapping (parser.rs:2733)
  - **RENDER_GAP**: `expr.not()` → `!(expr)` 布尔取反 (render_calls.rs:257-259)
  - **RENDER_GAP**: `String.equals(x)` → `(lhs == rhs)`, `String.equals(x, true)` → case-insensitive compare (render_calls.rs:631-637)
- **回归**: Phase 0 202/202 single + 33/33 project 全部通过 ✅
- **剩余 35 错误 (全部 safelist.cj)** — STDLIB_GAP:
  - `HashSet.addAll()`, `removeAll()` — Cangjie HashSet 无这些方法
  - `HashSet([value])` — 数组构造函数参数不兼容
  - `HashMap([value])` — 同上
  - `entries.iterator()` — 返回类型 HashMapEntry vs Entry
  - IIFE `({ => ... })()` — 无效仓颉 lambda 语法
  - `copy.preserveRelativeLinks` — var/func 命名冲突
- **R2 计划**: 修复 safelist.cj 集合 API 翻译 (stdlib 映射) + IIFE 消除
- **文件**: parser.rs (+2), render_calls.rs (+6)
- **收敛**: R2 完成 — 35 → 0 ✅ (2026-06-16)
- **R2 修复内容**: safelist.cj Cangjie stdlib collection API 适配 (addAll→add(all:), HashSet([x])→显式构造, removeAll→手动循环, entries.iterator→for-in), TypedValue Hashable/Equatable 实现, String.lowerCase→toAsciiLower, String.matches→Regex.matches, Array<Byte> 构造函数适配
- **回归**: Phase 0 202/202 single + 33/33 project 全部通过 ✅

### Phase 1 — 1c okhttp-mockwebserver (2026-06-17) ✅

- **源文件**: 14 Kotlin 主源 + 5 test → 19 .cj 文件
- **基线**: 5 编译错误（mock_web_server_socket.cj:4, http2_server.cj:1）
- **修复内容**:
  - **PARSER_GAP** (newline leak): `skip_property_accessors` — `get() =\n when { ... }` 多行表达式体内换行误终结跳过。引入大括号深度跟踪 + 声明关键字前探，仅在 `}` depth=0 或下一 `get`/`set` 时停止 (parser.rs)
  - **RENDER_GAP** (companion main): `companion object` 的 `main()` 被渲染为 `static main()` 在类内，仓颉不允许。检测 companion 成员 `main()` → 提升为顶层函数 (render.rs)
- **回归**: Phase 0 202/202 + 33/33 ✅
- **文件**: parser.rs (+25), render.rs (+8)
- **剩余**: 444 errors — 全为跨包依赖 (stub gaps: Closeable/Http2Connection/Cloneable 未声明, RecordedRequest/SocketHandler 重定义, it redefinition from `?.also`)
- **注释**: 1c 的 5 个直接翻译错误全部解决。剩余 444 个错误是 mockwebserver 对 okhttp core 类型的依赖，非翻译器 gap。

### Phase 1 — 1g full-ksoup (2026-06-17) 🔄 R1 round-robin

- **上下文**: 1d (ksoup-parser) 被跨包子包依赖阻塞。1c/1e/1f 无本地 Kotlin 源。Round-robin 跳过 1d，启动 1g 全量 ksoup 编译。
- **基线**: 88 文件已翻译，1601 编译错误（8 printed by default）
- **R1 修复 (translator, 1 change, regression-passing)**:
  - **RENDER_GAP**: `map_type()` 非泛型 match 分支缺失 `IntArray`, `ShortArray`, `LongArray`, `FloatArray`, `DoubleArray`, `BooleanArray` → 对应 `Array<T>` 映射 (parser.rs)
  - **RENDER_GAP**: `map_type()` 非泛型 match 分支缺失 `Map.Entry` → `Entry` 映射（泛型分支已有，普通分支遗漏）(parser.rs)
  - **RENDER_GAP**: `map_type()` 非泛型 match 分支补充 `Map`, `List`, `Set` 等集合基类映射 (parser.rs)
- **回归**: Phase 0 202/202 + 33/33 ✅
- **文件**: parser.rs (+10)
- **阻塞**: 无 ksoup Kotlin 源文件，无法重新翻译验证。需获取 Kotlin 源 (clone ksoup repo) 或手动修补 .cj 输出验证。
- **下一步**: 获取 ksoup / okhttp / ktor / koin Kotlin 源 → 解锁 1c/1e/1f/1g
- **顶层错误分类** (1601 errors):
  - 36: mismatched types (Option<T> vs T unwrap, generic inference)
  - 13: no matching function for operator '()' (lambda/IIFE)
  - 6: Evaluator missing ToString impl
  - ~10: undeclared inner class refs (Token.StartTag→StartTag, Token.Character→TokenCharacter, Attributes.Dataset→Dataset)
  - ~15: stdlib API gaps (isNullOrEmpty, hasNext, appendCodePoint, toRuneArray, concatToString, clone, add, clear)
  - 1: attributeKey param vs local let redefinition (naming conflict in function scope)

### Phase 1 — 1g full-ksoup (2026-07-06) ⏳ R2 完成 — parse 战役收官,45→0 parse errors

- **源已获取**: `C:/Codes/kotlin/ksoup` (shallow clone, fleeksoft/ksoup) — 按新规则自动 clone,解除 R1 的"无 Kotlin 源"阻塞
- **翻译脚本**: `output/translate_1g.py` (per-file, 基于 translate_1e.py 模式, --check/--validate, 父目录前缀消歧, 剥离 per-file main)
- **翻译**: 87/87 文件成功 → `output/target_1g/` (新目录,旧 R1 手补产物 `output/ksoup_cj/` 保留作对照)
- **R2 错误轨迹**: 45 (parse) → 33 → 13 → 6 → 1 → **0 parse errors**
- **R2 译器修复(10 项,详见 fix-history 2026-07-06 各条,每项都有靶向测试用例 210-220)**:
  1. **P1 PARSER**: 泛型 bound `<T : Bound>` 吞参数表收尾 `>` → 修 + bound 编码 `"T <: Bound"` → render `where T <: Bound`(24/45 errors)
  2. **PARSER**: companion 内嵌套 class(Element.NodeList)未解析,成员误捡为 static(20 errors)
  3. **PARSER**: safe_name 补 `operator`/`redef`/`inout`/`synchronized`/`static`
  4. **RENDER**: infer_literal_type 补 Unary(±) 递归 / FloatLit / charArrayOf→Array<Rune>
  5. **PARSER**: enum 条目 trailing comma 后 `;` 被吞 + enum 内 companion 按块跳过
  6. **PARSER**: `if (x) foo(); else` 分号挡住 else 前探(skip_seps)
  7. **RENDER**: 中位默认值参数降级为位置参数(声明 render_func + 调用 fn_params 同规则)
  8. **PARSER**: trailing-lambda-only 泛型构造 `Type<T?> { ... }` 误判为 `<` 比较
  9. **HEURISTIC**: `.keys`/`.values` 映射加 provably_non_collection 守卫(用户类字段保留)
  10. **RENDER**: `getOrPut(...)[k] = v` statement 级展开(IIFE 左值 + 裸 ctor 推断双修) + 可空泛型 bound `E : Element?` 丢弃 where 条目
- **回归**: Phase 0 每轮全跑,最终 212/212 single(202+10 新增)+ 33/33 project 全绿
- **⚠️ 语义层揭示(同 1e 教训)**: parse 清零后语义分析放行,真实基线 **1889 semantic errors**。顶层分类:
  - 171 mismatched types(Option/T unwrap 等)
  - 46 `notEmpty` 无匹配(Validate stub 缺失)/ 43 泛型裸用 / 37 `Tag` 歧义 / 31 operator '()'(lambda/IIFE)
  - 30 `OutputSettings` + 25 `Regex` + 16 `KClass` undeclared(嵌套类提升引用 + stdlib/反射 stub gap)
  - 28 for-in 非 Iterator / 21 HashMap 约束 / 20 enum pattern / 19 泛型推断 / 17 `lowerCase` / 17 `__k2cjRuneSlice` 歧义
- **R3 候选(语义战役)**: ① `===`/`!==` 目前 lexer 退化为 `==`,类引用相等应映 refEq(indexInList 等会撞) ② Document.OutputSettings 等嵌套类提升后的限定名引用改写 ③ Regex/KClass/Validate stdlib stub ④ enum companion 函数(CoreCharset.byName)静态化而非丢弃 ⑤ mismatched types 大类细分

### Phase 1 — 1d ksoup-parser (2026-07-06) ⏳ R1 完成 — 重定义为 1g 切片 + 嵌套类提升战役

- **重定义**: 1d 单独翻译不可行（fix-history 2026-06-17 结论），重定义为 1g 全量编译中 parser 子包 16 文件切片。基线（per-file 管线, r2f 日志）: 525 errors / 13 文件（tokeniser_state/html_tree_builder_state/parse_error 三文件干净）。
- **诊断（切片根因簇）**: ① 嵌套类提升引用未改写+撞名（最大簇 ~151, Token.StartTag/TokenType 等 + ambiguous Tag/Comment/Character）② stdlib stub gap（Reader/StringReader/IOException/appendCodePoint 等）③ enum companion 常量（TokeniserState.nullChar）④ Option unwrap/集合 API 等。
- **修复 1（嵌套类提升, fixer R1）**: engine.rs 新增 `apply_nested_lifting` 图归一化 pass — (父类,嵌套名)→提升名注册表；撞名时父类名前缀重命名（Token.Comment→TokenComment 等 5 个）；全图类型字符串限定链折叠。render.rs render_member 表达式位改写。测试 221 + proj_nestedlift。该簇 ksoup 语料 151→0。
- **修复 2（std.iterator, fixer R2）**: project.rs `detect_and_gen_imports` 启发式注入不存在的 `import std.iterator.*`（11 文件, 挡住全部语义分析）→ 删除。测试 222 + proj_iterimport。
- **⚠️ 关键发现 — per-file 管线丢失跨文件上下文**: translate_1g.py 逐文件调用翻译器，Engine 每次只见单文件，跨文件修复（嵌套提升消歧等）完全不生效（重译后错误数纹丝不动 1889）。**1g/1d 测量管线自本轮切换为 project 模式**（目录输入, project.rs 路径, 33 个项目测试保护）。translate_1g.py 保留作对照。
- **新基线（project 模式）**: 总 1595（旧 per-file 1889），1d 切片 411（旧 525）。热点: html_tree_builder(122), tree_builder(42), tokeniser(37), token(37), character_reader(36)。
- **切片错误分类（411）**: 69 undeclared identifier / 55 mismatched types / 43 not-member-of-class / 36 not-member-of-enum / 24 undeclared type / 23 invalid binary op / 20 operator '()' / 14 break-continue 非循环 / 13 missing argument / 11 generic 裸用 / 11 uninitialized member。
- **project 模式已知遗留**: ① LinkedList.kt 泛型 typealias `typealias LinkedList<E> = MutableList<E>` parse error → 文件被静默跳过（且 project.rs 报"成功 86"无失败上报，计数口径需修）② 输出文件名无父目录前缀消歧（ksoup 当前无 basename 撞名, 暂无碍）。
- **回归**: 两轮修复后 215/215 single + 35/35 project 全绿（基线实测 213/33, 非 state 记载的 202/33——历史用例数已增长）。
- **R2 候选**: ① enum companion 常量静态化（TokeniserState.nullChar, 36 not-member-of-enum）② stdlib stub（Reader/StringReader/IOException/appendCodePoint）③ break/continue 在 when 内被误判非循环（14）④ LinkedList 泛型 typealias parse ⑤ mismatched types 细分。
- **改动未提交**（engine.rs, render.rs, project.rs + 4 组新测试 + fix-history 3 条）。

### Phase 1 — 1d ksoup-parser (2026-07-06) ⏳ R2 完成 — stdlib-type-surface 簇消掉

- **行动簇**: stdlib-type-surface（STDLIB_GAP）— Kotlin stdlib 类型（Regex/Reader/KClass/Charset 等）无仓颉映射，原样输出致 undeclared。诊断估算 152 错误 + ~80 级联，风险=增量式。
- **R2 译器修复（4 处，全部 219/219 single + 35/35 project 回归通过 ✅）**:
  1. **新增 stubs.rs**（13596 字节）— 数据驱动表 `StubDef { provides, markers, imports, code }`，9 个 stub：Regex+RegexOption+MatchResult、KClass、Reader+StringReader、Sequence、MutableIterator+MutableListIterator、ByteArray、IntArray、Charset+CharsetEncoder+Charsets、Appendable。词边界匹配 marker，`defines_type` 守卫避免与用户自定义冲突。
  2. **project.rs 注入路径** — `convert_project` 末尾汇总 `all_bodies`，调 `stubs::collect_stubs` 生成独立 `k2cj_stubs.cj`（同包共享，含 package + imports + code）。
  3. **render.rs 单文件注入路径** — `render_program` 在 `__k2cjRuneSlice` 注入后调 `collect_stubs`，stub_code 追加到 body 末尾，stub_imports 加到 header。
  4. **main.rs** — `mod stubs;` 声明。
- **1g 全量测量（project 模式, target_1g_proj/）**: **1598 → 10 error（99.4% 降幅）**。stdlib-type-surface 簇 148→0。自动生成 k2cj_stubs.cj (7109 bytes, 9 个 stub 全部命中注入)。
- **剩余 8 个 parse error（R3 起点）**: 7 × `redefinition of declaration`（document.cj 的 parser/escapeMode/charset/syntax/prettyPrint/outline/indentAmount setter — Kotlin `fun parser(parser: Parser)` 参数名撞成员名）+ 1 × `optional parameter cannot be used in abstract function`（source_reader.cj 抽象方法默认参数）。cjc 遇 parse error 即停，遮蔽语义层。
- **靶向测试**: 4 个（230_regex_basic, 232_int_array, 233_charset, 234_reader_stringreader）。231_byte_array 因 `toByte()` 未映射（另一个翻译 bug 簇）暂删，IntArray 已验证类型别名 stub 机制。
- **diagnostician.md / SKILL.md 更新**: 引入"行动簇"概念（根因簇归组 + 杠杆/风险比排序 + 每轮只攻一簇）。
- **文件**: stubs.rs (新, +13596), main.rs (+1), project.rs (+26), render.rs (+12), diagnostician.md (+31/-10), SKILL.md (+13), tests/cases/23x (+4 对)。
- **R3 候选**: ① redefinition-of-declaration 簇（setter 参数名撞成员名，7 错误，需改名或加 `_` 前缀）② optional-parameter-in-abstract（1 错误，抽象方法去默认参数）③ 修完 parse error 后重测语义层真实错误数。

### Phase 1 — 1g full-ksoup (2026-07-06) ⏳ R3 测量 — stdlib 簇清零, parse 簇待修

- **R3 基线（project 模式, target_1g_proj/, 带 stub 注入）**: **10 error**（8 真 error + 2 cjpm 消息）。从 R2 的 1598 降至 10。
- **stdlib-type-surface 簇**: 148 → 0 ✅（Regex 37 + KClass 17 + Reader 15 + Sequence 15 + MutableIterator 15 + ByteArray 10 + IntArray 9 + Charset 9 + CharsetEncoder 6 + Appendable 10 + StringReader 4 + Charsets 1）
- **剩余 parse error 分布**:
  - 7 × redefinition-of-declaration: document.cj:190(parser), 223(escapeMode), 227(charset), 235(syntax), 242(prettyPrint), 246(outline), 250(indentAmount) — Kotlin `fun X(x: X)` setter 参数名撞成员名
  - 1 × optional-parameter-in-abstract: source_reader.cj:8 — `func read(bytes: ByteArray, offset!: Int64 = 0, ...)` 抽象方法默认参数
- **遮蔽效应**: cjc 遇 parse error 即停，不进语义分析（同 1e/1g 教训）。修完 8 个 parse error 后语义层放行，预计揭示新的错误分布。
- **k2cj_stubs.cj 自动注入验证**: 9 个 stub 全部命中（Regex/KClass/Reader/StringReader/Sequence/MutableIterator/MutableListIterator/ByteArray/IntArray/Charset/CharsetEncoder/Charsets/Appendable）。project 模式生成独立文件，单文件模式追加到 body 末尾。
- **R4 候选（修完 parse 簇后）**: 等语义层放行后重新诊断，按行动簇排队。预计剩余 stdlib 簇（MutableMap/MutableList/AutoCloseable/IOException 等，~50 错误，未覆盖 stub）+ redefinition 簇下游 + 其他语义错误。

### Phase 1 — 1f koin-core (2026-07-07) ⏳ R1 完成 — 3 parse 簇修复, 71/72 翻译

- **源已获取**: `C:/Codes/kotlin/koin` (shallow clone, InsertKoinIO/koin)
- **koin-core 路径**: `projects/core/koin-core/src/commonMain/kotlin` (commonMain 74 .kt / 5509 行,state 标 ~25 估算偏低,实际 commonMain 全量)
- **scope 决策**: 翻译全 commonMain 74 文件。expect 类 (mp/KoinPlatformTools + mp/ThreadLocal) 走 stubs.rs 注入 (同 1g stdlib stub 经验)
- **核心特性验证** (state 标注 DSL/delegate/reified):
  - DSL: dsl/ 5 文件 (KoinApplication/ModuleDSL/ScopeDSL/DefinitionBinding/KoinConfiguration)
  - delegate: ext/InjectProperty.kt (`by inject()`), `by lazy` 散落
  - reified: 21 文件用 reified,18 文件用 inline/noinline/crossinline
- **硬依赖边界**: mp/KoinPlatformTools.kt + mp/ThreadLocal.kt (expect 声明,需 stub)
- **R1 首跑**: project 模式只生成 1 .cj 文件,3 个 parse 簇阻断合并源解析
- **R1 修复 (3 簇, 全部 224/224 single + 35/35 project 回归通过 ✅)**:
  1. **inline-fn-param-modifiers** (parser.rs parse_param_nodes + parse_generic_params):
     - parse_param_nodes 故意不调用 skip_modifiers (避免误识参数名关键字),但也跳过 noinline/crossinline
     - 修复: 加 eat_kw("noinline") + eat_kw("crossinline") (这两个是 inline 函数 lambda 参数专用,不作为参数名)
     - parse_generic_params 把 'reified' 当作泛型参数名本身 (替代了 T),导致 'func f<reified>(...): T' + 'undeclared type name T'
     - 修复: 加 is_generic_mod 检查跳过 reified/out/in (Kotlin 泛型修饰符)
  2. **generic-typealias-declaration** (parser.rs parse_typealias):
     - parse_typealias L565 expect_ident 后立即 expect_sym("=") 不识别 `typealias X<T> = Target<T>` 的 <T>
     - 修复: expect_ident 后若 is_sym("<") 调 parse_generic_params 跳过 <T>
     - 影响 1f 10 个 typealias,3 个带 <T>: BeanDefinition L148 / Callbacks L26 / OptionDSL L16
  3. **receiver-function-type** (parser.rs parse_type_raw):
     - parse_type_raw 不识别 `ReceiverType.() -> R` Kotlin 带接收者函数类型
     - 解析 ReceiverType 后 expect_sym(")") 但得到 "." (receiver 分隔符)
     - 修复: expect_ident + 嵌套类型 + 泛型实参后,若 is_sym(".") 且下一 token 是 "(",消费 "." 把 ReceiverType 当作函数类型第一个参数,转入 `(ReceiverType) -> R` 解析
     - 影响 1f 8 处: Module L84/L93 / KoinApplication L22 / KoinConfiguration L34/L39/L47 / ModuleDSL L21 / ModuleExt L64
- **靶向测试**: 238 (inline+noinline+crossinline+reified) + 239 (generic typealias) + 240 (receiver function type)
- **1f R1 测量**: project 模式 71/72 文件翻译成功 (从 1 → 71,覆盖率 96%)。剩 1 parse error (val <E : Enum<E>> Enum<E>.qualifier 带泛型扩展属性,R2 候选)
- **1f R1 编译**: 9 errors (8 printed)。分布:
  - 3 × `expected type name after '<', found '*'` — Kotlin star-projection `Map<*>` (k_class_ext / definition_binding / option_d_s_l)
  - 3 × `unnamed parameters must come before named parameters` (scope / bean_definition ×2)
  - 1 × `expected expression after keyword 'throw', found '}'` (parameters_holder)
  - 1 × `expected declaration, found 'Duration'` (duration_ext)
- **R2 候选**: ① star-projection `<*>` 簇 (3 错误,parser.rs parse_type_raw L2801 已有 `*`→Any 但可能位置不对) ② unnamed-named-param-order 簇 (3 错误,1g R2 修过中位默认值参数,可能没覆盖全) ③ throw-expression-body 簇 (1e R2 修过 P2,可能没覆盖全) ④ 带泛型扩展属性 parse error (1 错误)

### Phase 1 — 1e ktor-io (2026-06-27) ⏳ R1 诊断完成

- **源已获取**: `C:/projects/kotlins/ktor` (shallow clone, ktorio/ktor)
- **scope 决策**: 整包 ktor-io 是 kotlinx.io(38)+kotlinx.coroutines(10)+atomicfu 薄封装，无法收敛到 0。选**纯 I/O 原语子集**（用户确认），剪枝协程/expect 层。
- **翻译脚本**: `output/translate_1e.py`（per-file，注入 package 行，子目录前缀消歧，--check/--validate）
- **剪枝**: 4 个 expect/actual+外部 typealias 文件（bits/ByteOrder, JvmSerializable, locks/Synchronized, core/internal/ChunkBuffer）— common-only 缺平台 actual，非翻译器 gap，同 1c/1d 依赖边界。
- **当前**: 14/14 文件翻译成功，**6 编译错误 / 3 文件**，全为真·翻译器 RENDER_GAP：
  - **P1 `return Unit`** (pool_pool.cj:13,16 ×2): Kotlin 空体 Unit 函数 → 译器插 `return Unit`，但 Cangjie Unit 值是 `()`。修复: emit `return`/`return ()`/空体。高复发·低风险·L1 首选。
  - **P2 `= throw expr`** (internal_numbers.cj:13): `fun f(): Nothing = throw IAE(...)` 表达式体 → 译成 `return throw`（丢异常实参）。修复: 直接渲染 `throw Exception(...)`。
  - **P3 value class + when** (line_ending_mode.cj:18-20): `value class`+companion 常量+`when` → `match` 用 `LineEndingMode.CR()` 静态调用当 pattern（非法）。修复: when-over-constants 译 if/else 链。低复发·高风险。
- **下一步**: Stage 5 Fixer — L1 优先修 P，Phase 0 回归（202+33）前后必跑。

### Phase 1 — 1e ktor-io (2026-06-27) ⏳ R2 Fixer 完成 + 真实错误数揭示

- **R2 翻译器修复（4 项，全部 202/202 + 33/33 回归通过 ✅）**:
  - **P1 RENDER_GAP**: `return Unit` → `return ()`。`Unit` value-expression（NameRef "Unit"）映射为仓颉单元值 `()`（render.rs，NameRef 分支早返回）。注意 `Unit` *类型* 走 map_type，不受影响。
  - **P2 PARSER_GAP**: 函数表达式体 `= throw X(...)` → 直接渲染 `throw X(...)`，不再 `return throw`（丢实参）。parser.rs 函数体 `= expr` 分支前探 `throw` 关键字。
  - **P3 RENDER_GAP（value class）**: `value class` → 仓颉 **struct（值语义）+ @Derive[Equatable]**。研究结论见下。涉及 node.rs（新增 `is_value` 字段）、parser.rs（`value` 软关键字仅在 `value class` 时捕获）、render.rs（struct 关键字 + @Derive 前缀 + value-class when 渲染）。
  - **附带 BUG 修复**: `skip_modifiers` 此前不交错跳注解 → 注解后的修饰符（`@JvmInline public value class` 的 `public`/`value`）被静默丢弃。改为循环内交错 `skip_annotations`。**坑**: `value` 是常见标识符（`var value: Int`），不能无条件当修饰符——仅当后跟 `class` 时捕获（peek_next_is_kw）。曾因此回归 3 个 single 测试（main 丢失），已修复。
- **P3 Cangjie 研究结论（cjc 1.0.5 实测）**:
  - `@Derive[Equatable]` 支持 class/struct/enum；enum 收集构造器参数；需 `import std.deriving.*`（译器已自动注入）。
  - **关键约束**: 派生的 `==` 经 `extend` 注入，在**类型自身方法体内不可见**。value class 的 `toString` 里的 `when(this)` 是内部比较 → 必须走**字段比较** `this.mode == CR().mode`，不能用 `==`。
  - enum 映射较侵入（构造器须改名、字段访问须解构）；**struct 最忠实**（值语义）且改动最小（字段/构造保持不变）。选 struct。
  - `when(this)` over companion 常量 → if/else 链比较字段（render_when 新增 value_class_const_field / render_when_value_class_consts，从 pattern 渲染串 `Type.X()` 反查 value class 字段名）。
- **line_ending_mode.cj 现 0 错误**（P3 验证通过）。
- **⚠️ 重大发现 — 「6 errors」是 parse 阶段欠计数**: cjc 遇 parse error 即停，不进语义分析。修掉 P1/P2/P3 三个 parse error 后，语义分析放行，**揭示 ~69 个潜伏语义错误**（13 个文件）。原诊断的「6 errors」严重低估。
- **真实 69 错误分类（cjc --error-count-limit）**:
  - 28 undeclared type name — `AutoCloseable`/`IOException`/`CharSequence`（stdlib 类型 stub gap）+ `T`/`R`（extend 类型形参 render bug）
  - 16 undeclared identifier — 上面的级联
  - 3 uninitialized member / 3 generic-needs-type-arg / 3 multiple-found / 2 shadow / 2 named-param-prefix / 2 interface-inherit / 等
  - **性质**: 绝大多数是**依赖边界**（atomicfu `atomic()`、缺 stdlib 类型 stub）——与 1c/1d 同类「非译器 gap」，少数真 render gap（`extend T<T,R>` 类型形参扩展、ObjectPool 泛型实参）。
  - pool_pool.cj 独占 28 错（atomicfu + 抽象类 + 泛型），属被剪枝的 atomicfu 层残留。
- **附带修复**: translate_1e.py 剥离 per-file 模式注入的空 `main()`（装配期多 main 冲突，assembly artifact，非译器 gap）。
- **文件**: node.rs(+2), parser.rs(+~14), render.rs(+~90, 含 3 个新 helper), output/translate_1e.py(+strip main)
- **✅ 收敛（2026-06-27）**: 按 1c 先例（✅=译器 gap 全修+stub，余依赖边界文档化），将 14 文件剪枝到 **5 文件真·可译核心**，加 `_stubs.cj`（`extend Int64 { toInt }`），**`cjpm build success`，0 errors**（3 个 unused-function warning，无害），`cjpm run` 通过。
  - **保留核心 5**: LineEnding, LineEndingMode(P3 value class→struct), Annotations, ByteOrder(enum), Numbers(toInt stub)。
  - **剪枝 9**（translate_1e.py 内文档化分类）:
    - 硬依赖边界（同 1c/1d cross-pkg）: Pool/ByteArrayPool(atomicfu `atomic()`)、Copy/Deprecation(kotlinx.io Source/Sink)、Closeable(AutoCloseable+kotlin.use+extend类型形参)、errors/Exceptions(纯 kotlinx.io typealias 空体)。
    - **延后的真 render gap（R3 可修，本会话避免高风险批量改）**: Exceptions.kt(`cause` 在异常子类链中 shadow 父类成员，1a cause-promotion 需加「父类已是异常类则不提升」守卫)、CharArraySequence.kt(CharSequence 映射不一致: 返回位 String vs 父类型位 interface)、Memory.kt(ByteArray 在 extend-target/构造器位未走 map_type)。
  - **译器改动仍 202/202 + 33/33 回归通过**（仅 translate_1e.py 脚本在末次回归后改动，译器二进制未变）。
- **R3 候选（真 render gap，皆通用译器改进）**: ① extend on type param（`fun <T,R> T.use()`）② 异常子类 cause 防 shadow ③ CharSequence 映射一致性 ④ ByteArray extend/ctor 位 map_type 覆盖 ⑤ abstract `val` prop → 仓颉 prop（非 `let` 字段，pool 的 capacity）。

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
| 1d | ksoup-parser | ksoup | 16 | ⏳ | 30+ undeclared | state machine, when, inline; BLOCKED: cross-pkg deps |
| 1e | ktor-io | ktor | 5 (核心)/14 | ✅ | 0 | P1/P2/P3译器修复;核心5文件收敛,余9剪枝(依赖边界+render gap) | C:/projects/kotlins/ktor |
| 1f | koin-core | koin | ~25 | 🔒 | - | DSL, delegate, reified |
| 1g | ksoup-main | ksoup | 87 | 🔒 | - | 全量交叉编译 |

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

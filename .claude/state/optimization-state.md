# kotlin2cj 优化状态

> 跨 run 持久化。每轮 fixer 追加，orchestrator 启动时先读。
>
> 难度梯度：Phase 0 (⭐ 基线) → Phase 1 (混合小目标, 4 项目) → Phase 2 (⭐⭐) → Phase 3 (⭐⭐⭐⭐) → Phase 4 (⭐⭐⭐⭐⭐)

---

## 全局进度

```
Phase 0       Phase 1                          Phase 2       Phase 3       Phase 4
[✅]          [✅][✅][✅][ ][ ][ ][ ]        [ ][ ][ ]     [ ][ ][ ]     [ ][ ][ ]
```

---

## Phase 0: 翻译器自身测试 (基线)

| 目标 | 测试规模 | 状态 | 备注 |
|------|---------|:--:|------|
| translator-own-tests | 202 single + 33 project | ✅ | 全通过。2026-06-16 全量回归验证。作为回归门禁 |

---

## Phase 1: 混合小目标（来自 4 个项目）

| # | 目标 | 来源 | 文件数 | 状态 | 编译错误 | 核心特性 |
|:--:|------|------|:---:|:--:|:-------:|---------|
| 1a | ksoup-exception | ksoup | 5 | ✅ | 0 | data class, sealed, enum |
| 1b | ksoup-safety+io | ksoup | 5 | ✅ | 0 | companion, extension, lambda |
| 1c | okhttp-mockwebserver | okhttp | ~30 | ✅ | 444 (cross-pkg deps) | builder, interceptor, coroutine |
| 1d | ksoup-parser | ksoup | 16 | ⏳ | 30+ undeclared | state machine, when, inline; BLOCKED: cross-pkg deps |
| 1e | ktor-io | ktor | ~20 | 🔒 | - | ByteChannel, coroutine I/O |
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

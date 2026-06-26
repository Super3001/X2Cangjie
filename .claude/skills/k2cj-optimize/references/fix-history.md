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


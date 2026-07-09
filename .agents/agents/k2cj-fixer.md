# k2cj-fixer — 翻译器修复

你是 kotlin2cj 的**外科医生**。接收诊断报告，在隔离的 worktree 中修改翻译器源码。

## 操作规程

1. **创建隔离 worktree**：`git worktree add ../k2cj-fix-<id> ksoup-entities-validation-2-2`
2. **阅读诊断报告**，理解错误的根因和修复方向
3. **按 SOC 算子层级修改**：

| 层级 | 范围 | 不改接口？ | 示例 |
|------|------|-----------|------|
| L1 | 单文件内 | ✅ | `render.rs` 加一个 match 分支 |
| L2 | 单文件内，可能改签名 | ⚠️ | `heuristics.rs` 新增方法 |
| L3 | 多文件 | ❌ | `node.rs` 新增 Kind 变体 → parser + render 联动 |

4. **优先 L1**。只有当 L1 无法修复时才升级。

## 修复模式参考

根据诊断类别，修复模式如下：

### PARSER_GAP
```rust
// parser.rs: parse_top_level() 或 parse_statement() 加分支
// 参考现有：skip_annotations()、skip_property_accessors() 等容错模式
```

### RENDER_GAP — 最常见
```rust
// render.rs: 在对应 Kind:: 的 match 分支加翻译规则
// 例：Index on String → 用 .get() 而非 []
// 参考：render_index() 方法
```

### HEURISTIC_GAP
```rust
// heuristics.rs: 在 looks_xxx() 中加 match 分支或方法名
// 例：looks_string() 里加 "toByteArray" 等方法名
```

### STDLIB_GAP
```rust
// stdlib_map.rs: 在映射表中加条目
// 例：Kotlin "String.toByteArray()" → 仓颉 "String.toRuneArray()"
```

**API-first（必须先过查证门）**：动手前按 `references/external-knowledge.md` 3.5 查证链
（① std → ② stdx → ③ 二方库表 → ④ TPC 三方库表 → ⑤ 兜底）确认有无现成实现，按
`references/autonomous-strategy.md` 修复手段偏好序 A 族选手段：**能映射真实 API 就映射
（map_type/stdlib_map.rs 或 cjpm 依赖），四级全无对应才写 stub**。stub 是永久负债
（终身跟随 stdlib 演进），映射维护费≈0——这不是风格偏好，是维护费的量级差。

## 外部知识

修复前**必须先加载**：

1. `references/kotlin-cangjie-patterns.md` — 检查是否已有已知模式可复用
2. `references/fix-history.md` — 检查同类错误是否已被修复（避免重复劳动）
3. 按需加载 `.github/skills/cangjie-std/` 等仓颉参考（见 `references/external-knowledge.md`；
   知识库权威清单见 `references/knowledge-registry.md`，新知识库从注册表发现，不硬编码）
4. **写 stub / 手写库实现前**：过查证门（external-knowledge.md 3.5，索引级 ≤5 次读取）

## 约束

- **必须在 worktree 中操作**，不污染主分支
- **改完必须编译通过**：`cargo build` in worktree
- **不删已有测试用例**：只增不减
- **新增 stub 未附查证记录不得提交**：fix-history 条目必须带 `- **查证**: 查①②③④，verdict …`
  行，说明查了哪些索引、为何确无现成 API/库（查证门见 external-knowledge.md 3.5）
- **修复后写入**：
  - `state/optimization-state.md` 追加本轮修改摘要
  - `references/fix-history.md` 追加修复记录
  - 如果是新模式 → 追加到 `references/kotlin-cangjie-patterns.md`

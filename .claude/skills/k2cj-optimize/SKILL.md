---
name: k2cj-optimize
description: kotlin2cj SOC 翻译器优化循环 — 发现目标代码库、翻译、编译、诊断、修复、验证的闭环自动化
version: 1.0.0
---

# kotlin2cj 优化循环

## 触发

- 用户说"优化 kotlin2cj"、"跑优化循环"、"翻译 ksoup 并修复"
- 定时：建议每 4 小时跑一次 `/goal "kotlin2cj 翻译 <target> 0 compile errors"`
- 手动：`/goal "k2cj-optimize target=ksoup"`

## 核心概念

这个 skill 是 SOC 理论第七节（LLM 作为通用算子）和架构 C（Loop Engineering）的融合实现：

- **SOC 框架**（已有）：`engine.rs` 的张力场 + 级联传播 + 慢驱动 — 这是翻译器内部的优化
- **Loop 框架**（本 skill）：翻译器外部的优化 — 把"翻译→编译→诊断→修复→验证"写成一个自动循环
- **LLM 即算子**：fixer agent 就是 SOC 第七节说的"通用重构算子" — 它替代手写的 2393 行 render.rs 规则库中未覆盖的部分

## 工作流

```
┌──────────────────────────────────────────────────────┐
│                  /goal 启动                           │
│  "kotlin2cj 翻译 ksoup 0 compile errors"             │
└──────────────┬───────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────┐
│  Stage 1: Explorer                                   │
│  确认目标代码库存在、可编译                            │
│  Agent: k2cj-explorer                                │
│  Guard: guards/1-explore-guard.md                    │
└──────────────┬───────────────────────────────────────┘
               │ PASS
               ▼
┌──────────────────────────────────────────────────────┐
│  Stage 2: Translator                                 │
│  运行 kotlin2cj 翻译目标代码库                         │
│  Agent: k2cj-translator                              │
│  Guard: guards/2-translate-guard.md                  │
└──────────────┬───────────────────────────────────────┘
               │ PASS
               ▼
┌──────────────────────────────────────────────────────┐
│  Stage 3: Compiler                                   │
│  编译仓颉输出 `cjpm build`                            │
│  Guard: guards/3-compile-guard.md                    │
│  ┌─ 0 errors → 🎉 结束，报告成功                     │
│  └─ >0 errors → 进入 Stage 4                        │
└──────────────┬───────────────────────────────────────┘
               │ HAS_ERRORS
               ▼
┌──────────────────────────────────────────────────────┐
│  Stage 4: Diagnostician                              │
│  分类编译错误（parser/render/heuristic/stdlib gap）    │
│  Agent: k2cj-diagnostician                           │
│  Guard: guards/4-diagnose-guard.md                   │
└──────────────┬───────────────────────────────────────┘
               │ PASS
               ▼
┌──────────────────────────────────────────────────────┐
│  Stage 5: Fixer                                      │
│  在 worktree 中修改翻译器源码，修复最高优先级的错误     │
│  Agent: k2cj-fixer (1 个错误 = 1 个 worktree)         │
│  Guard: guards/5-fix-guard.md                        │
└──────────────┬───────────────────────────────────────┘
               │ PASS
               ▼
┌──────────────────────────────────────────────────────┐
│  Stage 6: Verifier                                   │
│  全量回归测试（187 单文件 + 32 项目 + 新增针对性测试）  │
│  Agent: k2cj-verifier                                │
│  Guard: guards/6-verify-guard.md                     │
└──────────────┬───────────────────────────────────────┘
               │ PASS
               ▼
         回到 Stage 2（循环）
```

## 状态管理

`state/optimization-state.md` 是跨 run 的唯一真相源。

## 外部知识

本 skill 的知识层：

| 层级 | 位置 | 内容 | 加载者 |
|------|------|------|--------|
| L0 翻译模式 | `references/kotlin-cangjie-patterns.md` | Kotlin→Cangjie 已知翻译模式 | diagnostician, fixer |
| L1 修复历史 | `references/fix-history.md` | 历次修复记录（避免重复） | fixer |
| L2 优化目标 | `references/optimization-goals.md` | 10 项优化目标（G1-G10） | orchestrator |
| L3 语义保持 | `references/G10-semantic-preservation.md` | 差分测试设计 + 验证 stage | verifier, diagnosticator |
| L4 仓颉参考 | `.github/skills/cangjie-*/` | 仓颉语言/标准库/规范 | 按需加载 |
| L5 x2cj 翻译规则 | `~/x2cj-skills/skills/x2cj/rules/` | Java→Cangjie 已验证翻译规则（syntax/IO/线程/Android） | fixer, diagnosticator |
| L6 差分测试设施 | `~/x2cj/skills/x2cj-test/` | Java→Cangjie 差分测试工作流 + output-schema | verifier |
| L7 外部引入 | `references/external-knowledge.md` | 外部知识导入清单和加载规则 | orchestrator |

**知识复利**：每次 fix 不仅修 bug，还追加模式→修复历史→仓颉参考。x2cj-skills 的 Java 规则对 Kotlin 翻译有直接参考价值（共享 JVM 类型系统和大量 API）。

```markdown
## 当前目标: ksoup
## 迭代轮次: 3
## 总编译错误: 23 → 15 → 7

### 本轮 (R3)
- 修改: render.rs — Index on String → .get()
- 修改: heuristics.rs — looks_string 加 "codePointAt"
- 回归: 187/187 ✓, 32/32 ✓
- 新增测试: 214_string_codepoint_at
- 剩余错误: 7 (3 RENDER_GAP, 2 STDLIB_GAP, 1 HEURISTIC_GAP, 1 NODE_GAP)

### 历史
- R1: render.rs + stdlib_map.rs 修改, 错误 23→15
- R2: parser.rs 容错 + heuristics.rs 类型推断, 错误 15→7
```

## SOC 对齐

| SOC 概念 | k2cj-optimize 对应 |
|---------|-------------------|
| 语义依赖图 G | 诊断报告中错误的依赖关系链 |
| 张力 T(v) | 编译错误数 — T_verify |
| 崩塌 | fixer 修改一个模块 → verifier 触发依赖模块重验证 |
| 张力传导 | 一个 render 修改改变了某类型的翻译 → 所有用该类型的文件重新编译 |
| 慢驱动 | `/goal` 的迭代节奏 — 每次修复 1 个最高优先级错误，不并发 |
| 收敛判据 | `cjpm build` 0 errors + 全量测试 PASS |
| 张力热图 | 诊断报告中的 `fix_priority` 排序 |

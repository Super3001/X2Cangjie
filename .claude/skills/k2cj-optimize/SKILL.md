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

## Token 预算（显式覆盖全局规则）

本工作流**显式覆盖**全局 CLAUDE.md 规则 6 的预算（30k/task、100k/session）：

- **k2cj-optimize session 预算：5,000,000 tokens**（含全部子代理用量）
- 理由：一轮"翻译→编译→诊断→修复→回归"循环中仅 fixer 单轮就常需 100k+，全局预算与本工作流的粒度不匹配
- 仍需遵守的部分：逼近 5M 时把进度 checkpoint 到 `state/optimization-state.md` 后再继续或换 session；轮次收尾时报告本 session 的大致用量（fail loud，不静默超支）
- 不要因为用量超过 100k 而中断循环或建议换 session——只以 5M 为准

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

## 目标源码获取

**目标 git 仓库本地缺失时,默认 clone 到 `C:/Codes/kotlin/<repo-name>`,clone 完成后继续流程。** 不要因为本地没有 Kotlin 代码仓库而停下来等用户。

- 先检查已知位置(state 文件中记录的路径,如 `C:/projects/kotlins/ktor`),已存在则直接用,不重复 clone
- 缺失则 `git clone --depth 1 <upstream-url> C:/Codes/kotlin/<repo-name>`(浅克隆即可,只需源码不需要历史)
- clone 后把实际路径写入 `state/optimization-state.md` 对应目标的"本地工程"列

## 状态管理

`state/optimization-state.md` 是跨 run 的唯一真相源。

## 外部知识

本 skill 的知识来源分三部分：**项目私有**（本仓库 references/）+ **仓颉语言参考**（本仓库 `.github/skills/`）+ **外部共用**（x2cj-skills 仓库）。

x2cj-skills 路径按 Claude Code 启动环境解析（同一份磁盘内容）：
- Windows 启动：`C:/Codes/x2cj-skills`
- WSL 启动：`/mnt/c/Codes/x2cj-skills`

| 类型 | 位置 | 内容 | 谁加载 |
|------|------|------|--------|
| **私有** | `references/kotlin-cangjie-patterns.md` | Kotlin→Cangjie 翻译模式 | diagnostician, fixer |
| **私有** | `references/fix-history.md` | 历次修复记录 | fixer |
| **私有** | `references/optimization-goals.md` | 10 项优化目标（G1-G10） | orchestrator |
| **私有** | `references/G10-semantic-preservation.md` | 语义验证设计 | verifier |
| **仓颉参考** | `.github/skills/cangjie-std/` | 仓颉标准库 | diagnostician, fixer, semantic-guard |
| **仓颉参考** | `.github/skills/cangjie-lang-features/` | 仓颉语法特性 | diagnostician, semantic-guard |
| **仓颉参考** | `.github/skills/cangjie-stdx|toolchains|original-docs|regulations/` | 扩展库/工具链/官方文档/规范 | 按需 |
| **外部** | `<x2cj-skills>/skills/x2cj/rules/docs/kotlin/` | Kotlin→Cangjie 规则（31 文件，一级知识源） | diagnostician, fixer |
| **外部** | `<x2cj-skills>/skills/x2cj/rules/docs/java*/` | Java→Cangjie 已验证规则（补充） | fixer, diagnostician |
| **外部** | `<x2cj-skills>/skills/cangjie-dev/` | 仓颉开发参考（与 `.github/skills/` 重叠，补充用） | fixer, verifier |
| **外部** | `<x2cj-skills>/skills/x2cj-eval/` | LLM 语义评估（14 子维度） | verifier |
| 加载顺序和规则详见 `references/external-knowledge.md`。 | | | |

> 私有知识是项目累积的（每次 fix 追加模式+记录），外部知识是只读参考（从 x2cj-skills 查询）。两者不混放。

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

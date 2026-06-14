# x2cj-test 融合架构方案

> 将 x2cj-test 从手动 QA 流水线升级为架构 B（声明式 + Gate）+ 架构 C（Loop + State）的自动质量环路。

---

## 一、定位

```
x2cj（翻译）                x2cj-test（验证）                x2cj-eval（静态评估）
─────────────              ────────────────                ──────────────
Java → 仓颉 翻译           接收仓颉项目，验证翻译质量           LLM 逐文件对比 .java↔.cj
                            │                                 │
                            ├─ 编译检查                        ├─ API 映射正确性
                            ├─ 语义评估 ←── 接 x2cj-eval ──── ├─ 逻辑一致性
                            ├─ 生成 Java 测试                  ├─ 实现完整性
                            ├─ 翻译测试                        ├─ 语义正确性
                            └─ 跑测试 + 修复 + 报告             └─ 幻觉控制
```

x2cj-test 是 x2cj 的下游，x2cj-eval 是 x2cj-test 的入口门禁。

---

## 二、当前状态

| 维度 | 当前 | 问题 |
|------|------|------|
| 编排 | 1 个 525 行 SKILL.md 管全部 9 个 stage | 调度逻辑和子 skill 指令混杂 |
| Agent | 6 个 agent 散落，无 orchestrator 定义 | 角色边界模糊，orchestrator 有时自己写代码 |
| 质量 | 检查项口头约定（"覆盖率≥70%"） | 隐式，不可审计 |
| 触发 | 人说"跑 x2cj-test" | 手动，不自动 |
| 状态 | SKILL.md 内嵌进度描述 | 不持久，跨 run 丢失 |
| 知识 | 不引用外部 skill | agent 从零推导，每次重新学 |
| 评估 | Stage 8 编译+运行时修复，无静态语义评估 | 坏的翻译也跑完全流程才暴露 |

---

## 三、目标架构

### 目录结构

```
skills/x2cj-test/
├── agents/
│   ├── orchestrator.md          ← 只调度不执行（架构 B 铁律）
│   ├── explorer.md              ← 项目结构发现
│   ├── gate.md                  ← 只检查不修复，PASS / FIX / EARLY_STOP
│   ├── utgen-agent.md           ← Worker（保留）
│   ├── test-mock-agent.md       ← Worker（保留）
│   ├── translate-agent.md       ← Worker（保留）
│   ├── test-fix-agent.md        ← Worker（保留）
│   └── review-agent.md          ← Worker（保留，可选多 Reviewer）
├── skills/
│   ├── env/SKILL.md             ← 保留
│   ├── utgen/SKILL.md           ← 保留
│   ├── mock/SKILL.md            ← 保留
│   └── fix/SKILL.md             ← 保留
├── guards/
│   ├── 1-explore-guard.md       ← 新增：explorer 产出完整性
│   ├── 2-compile-eval-guard.md  ← 新增：cjpm build + x2cj-eval ≥75
│   ├── 3-mock-guard.md          ← 新增：mock 类生成完整性
│   ├── 4-utgen-guard.md         ← 新增：测试通过率 + 覆盖率
│   ├── 5-merge-guard.md         ← 新增：全量测试 + 覆盖率未退化
│   ├── 6-transprep-guard.md     ← 新增：仓颉侧环境就绪
│   ├── 7-translate-guard.md     ← 新增：测试翻译产物 cjpm build
│   ├── 8-fix-guard.md           ← 新增：cjpm test 全过 + fix-record
│   └── 9-report-guard.md        ← 新增：test-result.json 符合 schema
├── pipeline/
│   └── PLAN.md                  ← 独立：Gate Rules 矩阵 + Active Blockers
├── state/
│   └── eval-state.md            ← 跨 run 持久化：目标 + 评分 + 修复历史
├── gate-records/                ← Gate 审查记录（JSON）
└── SKILL.md                     ← 工作流知识（从 525 行拆到 ≈ 150 行）
```

### Agent 流水线

```
/goal "x2cj-test 验证 <target> 翻译质量"    ← 架构 C 触发
  │
Stage 1: Explorer ──→ Gate 1
  发现项目结构
  │ PASS
Stage 2: Compile + x2cj-eval ──→ Gate 2    ← 新增：入口静态评估
  cjpm build + LLM 语义打分
  │ PASS (≥75)                               FIX (<75)
  ▼                                           │
Stage 3: Mock 生成 ──→ Gate 3                退回 x2cj 修翻译
  │ PASS                                     （不浪费 3-7 的测试生成）
  ...
Stage 7: 翻译 Java 测试 ──→ Gate 7
  │ PASS
Stage 8: 编译修复 + 运行时修复 ──→ Gate 8
  │ PASS
Stage 9: 报告生成 ──→ Gate 9
  │ PASS
  🎉
```

### 架构标注

| 阶段 | 架构来源 | 说明 |
|------|---------|------|
| Agent 分角色 + Guard 显式化 | **B** | 声明式文件系统驱动 |
| Orchestrator 铁律"只调度不执行" | **B** | awesome-claude-agents 验证模式 |
| `/goal` 触发 + cron 定时 | **C** | 人走开，系统自己跑到收敛 |
| State 持久化 | **C** | 跨 run 记忆，不依赖 context |
| x2cj-eval 入口门禁 | **B+C** | 静态评估 → 坏翻译不浪费后续 stage |
| 外部知识加载 | **B** | agent 启动时加载 x2cj-eval/cangjie-std/rules |
| Gate records | **B** | 每次 gate 判定可审计 |

---

## 四、任务清单（17 项 · ~28h · 4 工作日）

### 🟡 架构 B 保留（内容改写）

| # | 任务 | 工时 | 说明 |
|:--:|------|:--:|------|
| 2 | Orchestrator 拆分 | 3h | 525行 SKILL.md → orchestrator agent.md (40行) + skill (150行) |
| 3 | Worker 标准化 | 4h | 6 个 agent 补 model/tools/output 规范 |
| 4 | PLAN.md 重构 | 2h | 独立 pipeline + Gate Rules 矩阵 + Blockers |
| 5 | 子 Skill 适配 | 2h | 4 个 skill 去 orchestrator 耦合 |
| 6 | 跨 Skill 调用 | 1h | Stage 7 委托模式 |

### 🔴 架构 B 新增（隐式→显式）

| # | 任务 | 工时 | 说明 |
|:--:|------|:--:|------|
| 7 | Gate Agent | 3h | 只检查不修复，PASS/FIX/EARLY_STOP |
| 8 | Guard 文件 ×9 | 6h | 每 stage 检查项显式化 |
| 10 | Gate 接入 | 3h | Worker→Gate→下一阶段 通用调度 |

### 🔵 架构 C 新增（时间循环）

| # | 任务 | 工时 | 说明 |
|:--:|------|:--:|------|
| 14 | Loop 机制 | 2h | `/goal` + cron：系统自动跑到验证通过 |
| 15 | State 持久化 | 1h | `state/eval-state.md` 跨 run 记录 |
| 16 | 外部知识链 | 1h | 接线：x2cj-eval skill + cangjie-std + x2cj rules |
| 17 | x2cj-eval 入口门禁 | 1.5h | Stage 2 插 x2cj-eval，<50 直接退回翻译 |

### 🟢 轻量

| # | 任务 | 工时 | 说明 |
|:--:|------|:--:|------|
| 11 | CLAUDE.md | 0.5h | AI Team 声明 |
| 12 | Explorer Agent | 0.5h | 独立 agent 文件 |
| 13 | Reviewer Agent | 2h | 可选：4-6 个 Reviewer 对抗审查 |
| 18 | Ledger→State 合并 | 1h | 不再单独 JSONL，所有记录走 state |

### 🗑 删除

| # | 原因 |
|:--:|------|
| 1 · 目录重组 | x2cj-skills 已有标准目录结构 |

---

## 五、4 天阶段

```
Day 1: 任务 2 (3h) + 任务 3 (4h)                          = 7h
       Orchestrator 拆分 + Worker 标准化

Day 2: 任务 4 (2h) + 任务 5 (2h) + 任务 7 (3h)            = 7h
       PLAN 重构 + 子Skill适配 + Gate Agent

Day 3: 任务 8 (6h) + 任务 6 (1h)                           = 7h
       9 个 Guard 文件 + 跨Skill调用

Day 4: 任务 10 (3h) + 任务 14-18 (6.5h) + 任务 11-13 (3h) ≈ 7h
       Gate接入 + Loop/State/知识链/eval门禁 + CLAUDE/Explorer/Reviewer
```

---

## 六、与 kotlin2cj 优化系统的对比

| | kotlin2cj 优化 loop | x2cj-test 融合方案 |
|---|---|---|
| **做什么** | 翻译器自我改进（改 render/heuristics/parser） | 翻译质量验证（不改翻译器） |
| **循环驱动** | 编译错误数 → 0 errors 收敛 | `/goal` 跑完全 9 stage 或 cron 定时 |
| **语义评估** | x2cj-eval 在 Stage 3.5（轻量替代运行时测试） | x2cj-eval 在 Stage 2（入口门禁，坏翻译不浪费后续） |
| **知识层** | L0-L7 七层，含 kotlin2cj 特定模式 | 三层：x2cj-eval + cangjie-std + x2cj rules |
| **外部依赖** | x2cj-skills rules + cangjie reference | 同 |
| **收敛判据** | G1(0 errors) + G10(≥75) | Gate 9 PASS |
| **自动修复** | ✅ fixer agent 改翻译器源码 | ❌ 退回 x2cj 让人/LLM 修 |

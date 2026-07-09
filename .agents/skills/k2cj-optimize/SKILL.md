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
- **Auto mode**：`/k2cj-optimize --auto [N]`（默认 N=20）— 启动自动进攻循环

## Auto Mode（自动进攻循环）

`/k2cj-optimize --auto N` 启动一个无人值守的优化循环，按 `autonomous-strategy.md` 三层决策架构自动选择 target / 簇 / 方法，循环 N 轮或直到所有 target 攻克完毕。

### 触发语法

```
/k2cj-optimize --auto         # 默认 N=20 轮
/k2cj-optimize --auto 5       # 指定 5 轮
/k2cj-optimize --auto 0       # 0 = 不限轮数，仅靠"所有 target 攻克"终止（慎用）
```

### 每轮 R 的流程

```
┌──────────────────────────────────────────────────────┐
│  R 轮开始                                             │
│   1. 读 state/optimization-state.md 获取当前所有      │
│      target 状态 (✅/⏳/🔒/🟡/❌)                     │
│   2. 层 1 自动选 target (autonomous-strategy.md)     │
│      - 优先 in-progress target (避免 context switch) │
│      - 否则选 🔒 target 中评分最高者                  │
│   3. 层 2 自动选簇 (P0-P7 优先级 + 量化打分)          │
│   4. 层 2.5 打包决策 (单簇 vs 多簇打包,5 条 AND)      │
│   5. 层 3 选方法 (L1/L2/L3 + 修复手段偏好序)         │
│   6. 执行修复 (Stage 2-6 流水线)                     │
│      - 翻译 → 编译 → 诊断 → 修复 → 回归              │
│   7. 重新测量错误数,更新 state 文件                  │
│   8. 自主循环判据 (autonomous-strategy.md):          │
│      - 有效率 ≥ 30% 且剩余 > 5 → 继续                │
│      - 有效率 < 10% 连续 2 轮 → 切换 target          │
│      - 剩余 < 5 → 当前 target 收尾                   │
│      - 触及 L3 → 按下方"L3 自动处理策略"降级,        │
│        非必要不上报人工                              │
│   9. R 轮结束,N -= 1                                 │
└──────────────┬───────────────────────────────────────┘
               │
               ▼
        N > 0 AND 有未攻克 target?
        ├─ YES → 回到 R 轮开始
        └─ NO → 循环结束,出报告
```

### 终止条件（任一触发即停）

1. **轮数用尽**：已完成 N 轮 R
2. **所有 target 攻克**：state 中所有 target 状态为 ✅ 收敛，无 🔒/⏳/🟡 target
3. **连续 3 轮无进展**：连续 3 轮有效率 < 10%（边际严重递减）。**进展以"累计消灭根因簇数"计，
   不以净错误数计**——净错误数平台期（如 1g 的 1598→10→10→10→10：R2-R4 每轮消一整簇、级联揭示
   新簇，净数不动）是 SOC 级联的常态，那三轮恰是战役最高产的三轮，不算零进展
4. **多 target 全 L3 阻塞**：≥ 3 个 target 都因 L3 簇无法降级标记为 🟡 blocked（极少数情况，见下方 L3 处理策略）

### L3 自动处理策略（非必要不上报人工）

L3（核心逻辑重构）触发时**不立即暂停**，按以下优先级尝试自动处理：

```
L3 触发 →
1. 尝试自动降级 (L3 → L2 + 辅助手段)
   - L3 → L2 + API 映射/stub 注入 (过查证门:有真实 API 先映射,四级无对应才 stub 绕过核心改动)
   - L3 → L2 + render 规则兜底 (用 render 处理边缘情况)
   - L3 → L2 + heuristic 启发式 (用启发式避免改类型推断)
2. 降级失败 → 尝试分阶段
   - 把 L3 拆成多个 L2 步骤,每个 L2 单独验证
3. 分阶段失败 → 保守放宽
   - 跳过该簇,标记为"已知限制",攻下一个簇
   - "已知限制"是**定格裁决(暂封,不是墓碑)**:须 ≥2 次独立确认(不同轮或不同 target 上复现"修不动
     或不值得修")才可标;标时在 state 写**重审条件**(如"仓颉 stdlib 出 Regex 后重审"、"回归面
     >300 后重攻"),条件满足即解冻。n=1 的单次失败不得做永久裁决
   - 该 target 标记 🟡 blocked,切换到其他 target
4. 只有 ≥ 3 个 target 都 🟡 blocked 且无法降级 → 上报人工审查
```

**原则：非必要不上报人工**。L3 触发时优先找降级路径，只有真正无法自动处理（如需要重新设计架构、触及不可逆语义变化、多 target 同时阻塞）才上报。

### 输出报告（循环结束时）

```
=== k2cj-optimize auto mode 报告 ===
运行轮数: N (实际完成 X 轮,提前终止原因: ...)
Token 用量: ~XXXk

各 target 进展:
- 1g ksoup-main: R4 → R6 (10 → 4 errors, -60%)
- 1f koin-core: R1 → R3 (9 → 1 errors, -89%)
- ...

新增靶向测试: 241/242/243 (3 个)
译器改动文件: parser.rs (+30), render.rs (+15)
git commits: abc1234, def5678, ...

L3 降级记录 (如有):
- L3 簇 X → 降级为 L2 + stub (成功)
- L3 簇 Y → 分阶段拆 3 个 L2 (成功)
- L3 簇 Z → 保守放宽,标记已知限制 (跳过)

下一轮建议:
- 优先攻 1f R4 (剩 1 parse error, 阻塞带泛型扩展属性)
- 1g R7 候选: 参数名 shadowing 簇 (3 errors)
```

### Auto mode 与手动模式的差异

| 维度 | 手动模式 (`/goal target=X`) | Auto mode (`--auto N`) |
|------|----------------------------|----------------------|
| target 选择 | 用户指定 | 层 1 自动 |
| 簇选择 | diagnostician + 用户确认 | 层 2 自动 |
| 打包决策 | 人工判断 | 层 2.5 自动 (5 条 AND) |
| 循环判据 | 每轮用户确认继续 | 层自主循环判据自动 |
| 终止 | 用户停止 | N 轮或所有 target 攻克 |
| 报告 | 每轮报告 | 循环结束统一报告 |
| L3 处理 | 人工审查 | 自动降级,非必要不上报 |

### Auto mode 的安全机制

- **每轮 checkpoint state**：R 轮结束必须更新 `state/optimization-state.md`，避免崩溃丢失进度
- **回归即回退**：auto mode 下回归失败自动回退到上轮 commit，不询问用户
- **L3 非必要不上报**：L3 触发时按"L3 自动处理策略"降级，只有多 target 全阻塞才上报人工
- **fail loud**：每轮结束 eprintln 当轮有效率 + 累计 token 用量
- **指标口径变更须会签**：把某类输出剔出错误统计（如"2 条 cjpm 消息不算编译错误"）是比改代码更
  永久的裁决——改口径比改译器更容易让数字变好看。须在 state 记决策日志 + 独立复核（人工或
  冷启动 subagent），不得由当轮 agent 单方拍板
- **防刷软柿子（可选，长跑启用）**：每 5 轮派一个独立冷启动 subagent 只读 state 战报（不读代码、
  不读当轮上下文），回答"战役在逼近'翻译真实世界 Kotlin'的目标，还是在养指标"

## Token 预算

- **日预算 100M tokens**（用户环境配置，足够 auto mode 长跑）
- **不设 session 上限**：auto mode 不因 token 用量中断循环，只以"N 轮完成"或"所有 target 攻克"为终止条件
- **fail loud**：每轮结束报告当轮用量 + 累计用量，但不静默超支也不主动停
- **唯一中断场景**：日预算 100M 真实耗尽（极端情况，按 L3 处理策略的"保守放宽"跳过当前簇，等次日预算恢复）

## 核心概念

这个 skill 是 SOC 理论第七节（LLM 作为通用算子）和架构 C（Loop Engineering）的融合实现：

- **SOC 框架**（已有）：`engine.rs` 的张力场 + 级联传播 + 慢驱动 — 这是翻译器内部的优化
- **Loop 框架**（本 skill）：翻译器外部的优化 — 把"翻译→编译→诊断→修复→验证"写成一个自动循环
- **LLM 即算子**：fixer agent 就是 SOC 第七节说的"通用重构算子" — 它替代手写的 2393 行 render.rs 规则库中未覆盖的部分

### 行动簇（可行动的根因簇）

诊断阶段的核心产出单位。编译错误是"症状"，不是"病因"——诊断的工作是把 N 个错误**按同一个翻译器缺陷归组**：同组错误只需改翻译器的一处逻辑就能全部消失，这样的一组叫一个**根因簇**。归组的抓手是错误消息模板 + 涉及的标识符名聚类（如 35 处 `undeclared 'Regex'` + 13 处 `undeclared 'Reader'` 同属 STDLIB_GAP 簇）。

"**可行动**"是选簇标准，包含两个维度，缺一不可：

1. **修法明确**：能说清改哪个模块、怎么改、怎么写靶向测试
2. **风险可控**：改动对已有测试的波及面可预估（增量式 > 局部改写 > 核心逻辑重构）

**可行动 ≠ 最大**。选簇时杠杆（错误数+级联）和风险要一起看：一个 90 错误的簇若要动类型推断核心（如 Option 自动解包），宁可先修 150 错误但纯增量的 stdlib 映射/stub 簇。高杠杆高风险的簇不是不修，是排在低风险簇之后、等回归测试面变厚了再修。

**API 优先于 stub（查证门）**：符号/类型缺失族的修复手段按"std 真实 API 映射 > stdx/二方库 >
TPC 三方库 > 最小 stub 兜底"排序（唯一权威序在 autonomous-strategy.md 修复手段偏好序）。
写任何 stub / 手写库实现前必过查证门（external-knowledge.md 3.5：索引级 ≤5 次读取，查证链
权威顺序见 knowledge-registry.md）。WHY：stub 是永久负债，映射维护费≈0——同为纯增量，
负债量级天差地别。

### 经济收敛与先兆指标（价格系统）

- **收敛判据的经济口径**：目标是"0 个修复期望收益为正的错误"，机械 0 errors 是其特例。长尾错误过
  **知止之秤**：编码+维护之费（如为全语料只出现一次的类型补 stub 并永久跟随仓颉 stdlib 演进）≥
  常驻处理的摊销之费（翻译后由 fixer 手工补一次）→ **主动定格**——与 🟡 本质不同：🟡 是"现在
  打不过"，秤称出的是"打赢了也不值"。定格记账 + 重审条件后即计收敛。1g 剩余 10 错的分账示例：
  3 个纠缠 shadowing（挂"待回归面变厚"）+ 5 个长尾 undeclared type（称秤，负值则定格）+
  2 个 cjpm 消息（指标口径变更，须会签）——分账完毕即"经济收敛"，不必死磕。
  **秤上有一项本可为零的维护费**：若真实 API 存在，映射方案的维护费≈0（官方替你演进），stub 则是
  永久负债——这是查证门（external-knowledge.md 3.5）的经济学依据：查证花 ≤5 次索引读取，
  省下的是终身跟随费
- **两个先兆指标**（每轮一除，写进 state，让转移先于撞墙）：
  - **每错成本曲线**：当轮 token ÷ 当轮消灭错误数。1g 实测每轮消错数 R2≈1588 → R3 8 → R4 6，
    断崖式下跌即"山穷之兆"——提示该 target 逼近经济均衡，宜转向高杠杆目标（如剩 1 个 parse error
    的 1f），杠杆完胜刮地皮
  - **规则密度**：新增规则/stub 数 ÷ 当轮消灭错误数。R2 为 9 stub/148 错 ≈ 0.06（泛化极好）；
    若某轮要 3 条特例 render 规则换 3 个错（≥1），泛化弧线已弯不动，在用特例换绿灯——止或剪枝之时。
    映射条目与 stub 同计分子，但**负债权重不同**（映射≈0，stub=永久）；密度劣化时先检查
    是否有 stub 可换真实 API 映射
- **剪枝轮（收缩算子）**：规则密度劣化时对 render.rs/stubs.rs 跑剪枝——**首选剪枝动作是
  "退役 stub 换真实 API 映射"**（净负债下降最多），其次合并特例为通用规则、退役摊销为负的
  stub。**简化计为进展**，与进攻轮同权入锁敌评分；以净规则数与净覆盖变化计，防刷分。
  存量候选队列见 state「剪枝轮候选（存量 stub 整改）」节
- **天花板估计（可选件，长战役配）**：抽 ~500 个目标语料的 Kotlin 构造，标"原则上可规则翻译 /
  本质需语义判断"（协程、反射、注解处理器多落后者），得"结构化覆盖上限约 X%"（带日期，仓颉
  stdlib 大版本后重估）。它给零进展定性：ktor（协程重）上零进展 = 贴天花板该停；ksoup（DOM 解析、
  无协程）上零进展 = 打法错了该换簇

默认每轮只攻**一个**行动簇（慢驱动），修完全量回归 + 重新测量，让下一轮诊断基于新的错误分布——因为消掉一个簇常会揭示或改变其他簇（1e/1g 都发生过 parse 簇清零后语义错误放量）。这就是 SOC 的张力热图：`fix_priority` 排序本质上是"按（杠杆/风险）比降序排列的行动簇队列"。

**批量三闸门**（层 2.5 打包决策的精炼判据；旧 5 条 AND 继续兼容）——多簇同轮须全过三门，任一不过退回单发：

1. **遥测够厚**：回归面成熟且被信任（当前 221+35 已具备；Phase 0 早期回归面新建时强制单发）
2. **都可逆**：改动 git revert 即除。**不可逆裁决**（标"已知限制"、改指标口径）剥出走慢轨：
   ≥2 次采样 + 单独归因 + 重审条件，不随批量走快车道
3. **互相正交**：无共享地盘——如 R3（engine.rs CtorParam 检测）⊥ R4（parser.rs build_also），
   可同批；而 it-shadowing 与"参数名 shadowing"同属改名家族、都要动 rename 逻辑，**纠缠必须单发**。
   批量炸了二分归因，但二分只能拆正交因，交互效应非二分可拆——这是第三门存在的理由

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
│  全量回归测试（221 单文件 + 35 项目 + 新增针对性测试）  │
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
| **私有** | `references/knowledge-registry.md` | **知识库注册表**（全部知识库的唯一权威清单 + 查证链位次 + 接入协议；新增知识库=加一行） | 全部 agent |
| **私有** | `references/autonomous-strategy.md` | 自主选择进攻方向的策略（三层决策架构 + 量化打分 + 修复手段偏好序唯一权威） | orchestrator, diagnostician |
| **私有** | `references/kotlin-cangjie-patterns.md` | Kotlin→Cangjie 翻译模式 | diagnostician, fixer |
| **私有** | `references/fix-history.md` | 历次修复记录 | fixer |
| **私有** | `references/optimization-goals.md` | 10 项优化目标（G1-G10） | orchestrator |
| **私有** | `references/G10-semantic-preservation.md` | 语义验证设计 | verifier |
| **仓颉参考** | `.github/skills/cangjie-std/` | 仓颉标准库 | diagnostician, fixer, semantic-guard |
| **仓颉参考** | `.github/skills/cangjie-lang-features/` | 仓颉语法特性 | diagnostician, semantic-guard |
| **仓颉参考** | `.github/skills/cangjie-stdx|toolchains|original-docs|regulations/` | 扩展库/工具链/官方文档/规范 | 按需 |
| **外部** | `<x2cj-skills>/skills/x2cj/rules/docs/kotlin/` | Kotlin→Cangjie 规则（31 文件，一级知识源） | diagnostician, fixer |
| **外部** | `<x2cj-skills>/skills/x2cj/rules/docs/java*/` | Java→Cangjie 已验证规则（补充） | fixer, diagnostician |
| **外部** | `<x2cj-skills>/skills/x2cj/rules/{sdk,tpc}-dependency-mapping.md` | **二方库/TPC 三方库映射表**（查证门 ③④：写 stub 前必查有无现成库） | diagnostician, fixer |
| **外部** | `<x2cj-skills>/skills/cangjie-dev/` | 仓颉开发参考（与 `.github/skills/` 重叠，补充用） | fixer, verifier |
| **外部** | `<x2cj-skills>/skills/x2cj-eval/` | LLM 语义评估（14 子维度） | verifier |
| 加载顺序和规则详见 `references/external-knowledge.md`。 | | | |

> 私有知识是项目累积的（每次 fix 追加模式+记录），外部知识是只读参考（从 x2cj-skills 查询）。两者不混放。

```markdown
## 当前目标: ksoup (1g full-ksoup, project 模式)
## 迭代轮次: 4
## 总编译错误: 1598 → 10 → 10 → 10 → 10 (R1→R2→R3→R4)

### 本轮 (R4 — also lambda it-shadowing)
- 行动簇: it-shadowing — also lambda 内联 `let it = _also_it` alias decl 撞外部 lambda 的 `it` 参数
- 修改: parser.rs — build_also 重构,去掉 alias decl;新增 rename_namerefs_in_subtree 递归改 body 的 `it` NameRef → `_also_it`
- 回归: 221/221 ✓, 35/35 ✓
- 新增测试: 237_also_lambda_it
- 剩余错误: 10 (3 redefinition 参数名 shadowing + 5 undeclared type 未覆盖 stdlib + 2 cjpm 消息)

### 历史
- R1: engine.rs apply_nested_lifting + project 模式切换, 1g 1889→1595 (project 模式)
- R2: stubs.rs 9 个 stdlib stub + project.rs/render.rs 注入, 1g 1598→10 (stdlib-type-surface 簇 148→0)
- R3: engine.rs CtorParam 冲突检测 + render_interface 默认参数 strip, 1g 8 setter redefinition→0
- R4: parser.rs build_also it-shadowing 修复, 1g 6 it redefinition→0, 新显现 5 undeclared type
```

> 数字基线 235+36 = 271 测试用例(2026-07-09 1g R5 实测)。Phase 0 起点为 202+33 = 235 (2026-06-14)。

## SOC 对齐

| SOC 概念 | k2cj-optimize 对应 |
|---------|-------------------|
| 语义依赖图 G | 诊断报告中错误的依赖关系链 |
| 张力 T(v) | 编译错误数 — T_verify |
| 崩塌 | fixer 修改一个模块 → verifier 触发依赖模块重验证 |
| 张力传导 | 一个 render 修改改变了某类型的翻译 → 所有用该类型的文件重新编译 |
| 慢驱动 | `/goal` 的迭代节奏 — 每次修复 1 个最高优先级错误，不并发 |
| 收敛判据 | `cjpm build` 0 errors + 全量测试 PASS；经济口径：0 个修复期望收益为正的错误（负值仗定格记账亦计收敛） |
| 张力热图 | 诊断报告中的 `fix_priority` 排序 |

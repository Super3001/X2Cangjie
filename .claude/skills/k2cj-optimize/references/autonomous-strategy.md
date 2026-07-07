# 自主选择进攻方向的策略

> 本文件是 k2cj-optimize 工作流的决策参考。orchestrator/diagnostician 在选择"攻哪个 target / 哪个簇 / 用什么方法"时按此策略打分排序。
>
> 来源：R0-R4 + 1f R1 实战经验总结（2026-07-07）。

---

## 三层决策架构

```
┌─────────────────────────────────────────┐
│  层 1: 目标选择 (哪个 target)            │
│  - 活跃优先 / 遮蔽最浅 / 杠杆最大        │
└──────────────┬──────────────────────────┘
               ▼
┌─────────────────────────────────────────┐
│  层 2: 簇选择 (哪个行动簇)               │
│  - parse 优先 / stub 优先 / L1 优先      │
│  - 量化打分: 杠杆 + 复用 - 风险          │
└──────────────┬──────────────────────────┘
               ▼
┌─────────────────────────────────────────┐
│  层 3: 方法选择 (L 级别 + 修复手段)      │
│  - L1 默认 / L2 失败 2 次 / L3 触核心    │
│  - stub > 关键字跳过 > map_type > SOC   │
└─────────────────────────────────────────┘
```

---

## 层 1: 目标选择策略

### 优先级决策树

```
活跃 target 有 in-progress 状态?
├─ YES → 继续攻当前 target (避免 context switch 成本)
│        ├─ 本轮有效率 ≥ 30% → 继续
│        ├─ 本轮有效率 < 10% 连续 2 轮 → 切换
│        └─ 剩余错误 < 5 → 完成收尾或换目标
└─ NO → 在 🔒 target 中选最优
         评分 = error_count × 10 + 跨目标复用面 × 15
                  - parse_error_count × 5 (parse 遮蔽成本)
         选评分最高的
```

### 目标切换判据

- **继续当前**：剩余错误 > 5 且本轮有效率 ≥ 30%
- **切换目标**：剩余错误 < 5（接近收敛）或连续 2 轮有效率 < 10%（边际递减）
- **暂停 + 总结**：触及 L3（核心逻辑重构）或连续 3 轮无进展

### 实战参考

| 切换场景 | 触发 | 实例 |
|---------|------|------|
| 接近收敛 | 剩余 < 5 error | 1g R4 后剩 10 error，未切换（>5） |
| 边际递减 | 连续 2 轮有效率 < 10% | 1g R3→R4 有效率 0%（10→10），但仅 1 轮 |
| 触核心 | L3 改动 | 未发生 |

---

## 层 2: 簇选择策略

### 簇优先级排序（基于实战经验）

| 优先级 | 簇类型 | 理由 | 实战验证 |
|:--:|------|------|------|
| P0 | **parse 簇** (阻塞翻译) | 修了才能解锁语义诊断 | 1g R2-R4, 1f R1 |
| P1 | **stub 簇** (stdlib 类型映射) | 杠杆最大，纯增量 | 1g R2 (99.4%) |
| P2 | **关键字跳过簇** (Kotlin 修饰符) | L1 + 2-3 行，风险最低 | 1f R1 inline-mods |
| P3 | **map_type 映射簇** | L1，单点修复 | 1g R2 |
| P4 | **render 规则簇** (中位默认值等) | L1-L2，已有规则扩展 | 1g R2/R3 |
| P5 | **SOC 检测簇** (命名冲突) | L2，新 pass | 1g R3 |
| P6 | **parser 重构簇** (lambda/作用域) | L2-L3，高风险 | 1g R4 |
| P7 | **类型推断核心簇** (Option unwrap) | L3，最后手段 | 未启动 |

### P0 优先的精确判据

P0 parse 簇优先是因为"parse error 遮蔽语义层"。但**当语义层已显现时**（cjc 已报编译错误），剩余 parse error 若只阻塞个别文件、不遮蔽语义诊断，可降级为 P3 处理。

判据：
- parse error 数 > 当前已显现语义错误数 → P0（遮蔽严重）
- parse error 阻塞 > 50% 文件 → P0（覆盖率损失大）
- 否则 → 降为 P3（按 priority 量化打分）

### 量化打分公式

每个簇打分：

```
priority = leverage_score + reuse_score - risk_score

leverage_score = error_count × 10 + cascade_count × 5
reuse_score    = cross_target_reuse × 15
risk_score     = L_level × 20 + files_changed × 5
```

**选 priority 最高的簇**（P0 优先原则满足后）。

### 遮蔽效应预判

- 修完 parse 簇后，预计显现 N 个语义簇（N ≈ 当前文件数 × 0.1-0.3）
- 1g R2 教训：1598 清零后语义层放行，真实错误数可能远大于 parse 阶段计数
- 1e R2 教训：6 个 parse error 清零后揭示 69 个语义错误
- **预判价值**：修 parse 簇前评估"会显现多少新簇"，决定是否需要预留 token 预算

---

## 层 3: 方法选择策略

### L 级别升级判据

| L 级 | 触发条件 | 修复手段 |
|:--:|------|------|
| L1 | 默认 | 关键字跳过 / map_type / stub 数据驱动表 / render 规则扩展 |
| L2 | L1 失败 2 次 **或** 错误数 > 50 | SOC 新 pass / parser 重构 / render helper 新增 |
| L3 | L2 失败 2 次 **或** 触及类型推断核心 | 类型推断重写 / 跨 pass 数据流改造 |

### 修复手段偏好序

1. **stub 注入**（stubs.rs 数据驱动表）— 纯增量，零核心改动
2. **关键字 eat_kw 跳过**（parse_param_nodes / parse_generic_params）— 2-3 行
3. **map_type 映射**（parser.rs map_type 函数）— 单点修复
4. **render 规则扩展**（render.rs 已有 helper 加分支）— 局部改写
5. **SOC 检测新 pass**（engine.rs）— 新逻辑但不改核心
6. **parser 重构**（build_also / rename_namerefs_in_subtree）— 高风险

---

## 自主循环判据

每轮 R 完成后自动判断：

```
本轮有效率 = (上轮错误数 - 本轮错误数) / 上轮错误数

IF 本轮有效率 ≥ 30% AND 剩余错误 > 5:
    → 继续当前 target 攻下一簇
ELIF 本轮有效率 < 10% 连续 2 轮:
    → 切换 target (边际递减)
ELIF 剩余错误 < 5:
    → 当前 target 收尾，切换下一个 🔒 target
ELIF 触及 L3:
    → 暂停 + 总结 + 标记人工审查
ELSE:
    → 继续当前 target
```

### 有效率计算的特殊情况

- **parse 簇修复**：错误数可能不减反增（遮蔽效应显现新簇）。此时用"翻译覆盖率"替代错误数：`有效率 = (本轮翻译文件数 - 上轮) / 上轮`
- **stub 簇修复**：错误数骤降（99.4% 经验）。有效率 ≥ 90% → 强继续
- **render 规则簇**：错误数稳定下降 10-30%。有效率 10-30% → 继续

---

## 跨目标知识复用机制

### 自动复用判据

- 当前 target 修的 bug 模式（如 SOC CtorParam 冲突）→ 自动检查其他 target 是否有同类错误
- 复用面 = 受益 target 数 × 受益错误数
- 复用分（reuse_score）计入簇 priority

### 已积累的可复用修复

| 修复 | 来源 | 可复用到 |
|------|:--:|------|
| stdlib stub 机制 | 1g R2 | 1f (MutableMap/MutableList/AutoCloseable) |
| SOC CtorParam 冲突 | 1g R3 | 1f (koin setter) |
| throw 表达式体 | 1e R2 | 1f (parameters_holder throw-expr 簇) |
| 中位默认值参数降级 | 1g R2 | 1f (unnamed-named-param 簇) |
| also lambda it-shadowing | 1g R4 | 1f (koin DSL 链式) |
| generic typealias | 1f R1 | 1g/1c/1e (如有 typealias) |
| receiver-function-type | 1f R1 | 1g/1c/1e (如有 ReceiverType.() -> R) |
| noinline/crossinline/reified 跳过 | 1f R1 | 任何 Kotlin inline 函数 |

### 复用检查流程

修完一个簇后，自动检查：
1. 该 bug 模式是否通用（非 target 特定）
2. 在其他 target 的 .cj 输出 grep 同类错误
3. 若有，标记为"可跨目标复用"，下次该 target 启动时优先修

---

## 当前应用示例（1f R2 进攻方向选择）

### 层 1: 目标选择

- 1f: in-progress, R1 刚完成，翻译 1→71 文件（有效率极高）
- 1g: in-progress, R4 完成，10 error（本轮有效率 0%，但仅 1 轮）
- **决策**：继续 1f（有效率更高，进展更明显）

### 层 2: 簇选择（1f R2 候选簇打分）

| 簇 | error | cascade | L | reuse | priority |
|---|:--:|:--:|:--:|:--:|:--:|
| 带泛型扩展属性 (parse) | 1 | 高 | L2 | 通用 | 10 + 15 - 45 = -20 |
| unnamed-named-param-order | 3 | ? | L1 | 1g R2 已修过，复用强 | 30 + 30 - 25 = 35 |
| `<*>` star-projection | 3 | ? | L1 | 1g 也可复用 | 30 + 15 - 25 = 20 |
| throw-expression-body | 1 | 0 | L1 | 1e R2 已修过，复用强 | 10 + 30 - 25 = 15 |
| duration-declaration | 1 | 0 | L1-L2 | 未知 | 10 + 0 - 25 = -15 |

### P0 判据应用

1f 的 1 个 parse error 只阻塞第 72 文件，9 个编译错误已显现（不依赖第 72 文件）。按 P0 精确判据：
- parse error 数 (1) < 已显现语义错误数 (9) → 不构成严重遮蔽
- 阻塞文件数 (1/72) < 50% → 覆盖率损失小
- **降级为 P3**，按 priority 量化打分

### 决策结果

按 priority 最高：**unnamed-named-param-order 簇（priority 35）**。

理由：
1. priority 最高（35）
2. L1 风险低
3. 跨目标复用强（1g R2 已有规则，1f 扩展到构造器参数分支，反向能加固 1g）
4. 1g R2 fix-history 备注"构造器参数分支未动（无实例）"——1f 提供实例

---

## 策略演进规则

本策略文件本身按经验积累演进：
- 每次新 target 收敛后，回顾本轮决策是否正确
- 错误决策（如选了高 priority 簇但修不动）→ 修正打分公式
- 新经验（如新修复手段）→ 加到"可复用修复"表
- 演进记录在 fix-history.md 标记 "STRATEGY UPDATE"

# SOC 理论 ↔ kotlin2cj Rust 实现对照解读

> 对照 SOC-theory.md 的十个章节，逐段映射到 `kotlin2cj/src/` 中的 Rust 代码。

---

## 一、决策传播问题 → 项目定位

SOC 理论第一节指出：跨语言翻译的难点是**决策传播**——局部选择改变全局签名。

kotlin2cj 的 `main.rs:1-2` 直接声明了自己的定位：

```rust
//! kotlin2cj —— 基于自组织临界性（SOC）局部规则的 Kotlin→仓颉翻译器。
```

这不是一个传统的树遍历翻译器（逐节点直译），也不是一个全局优化器。它选择 SOC 第三条路：**只定义局部规则，让系统自发收敛**。

---

## 二、语义依赖图 G=(V,E) → `node.rs`

### 2.1 节点 V：翻译单元

SOC 理论建议粒度取**函数/方法级，辅以类型定义节点**。`node.rs` 的 `Kind` 枚举正是这个设计：

| SOC 理论 | `node.rs` 实现 |
|----------|---------------|
| 函数翻译单元 | `Kind::Func { name, params, ret, body, .. }` |
| 类型定义 | `Kind::Class { name, members, .. }`, `Kind::Enum`, `Kind::TypeAlias` |
| 变量声明 | `Kind::VarDecl { mutable, name_node, ty, init, .. }` |
| 表达式/语句 | `Kind::If`, `Kind::While`, `Kind::Call`, `Kind::Binary`, … |

每个节点携带一个 SOC 状态向量 `State`（见下一节）。

### 2.2 边 E：带类型的多重边

SOC 理论定义了四种边类型，kotlin2cj 实现了其中两种核心边：

| SOC 边类型 | node.rs 代码对应 |
|-----------|-----------------|
| **调用边**（签名耦合） | `Node.dep → NodeId` + `Node.dependents: Vec<NodeId>` — 标识符引用→声明的依赖链（`node.rs:325-327`） |
| **数据流边** | 隐式通过 `parent` 父子关系 + `children_of()` 句法边（`node.rs:316-331`） |
| 效应边 | 未显式建模（不在当前版本范围） |
| 生命周期边 | Kotlin→仓颉 场景不需要（无指针逃逸问题） |

依赖边在 `engine.rs:42-48` 建立：

```rust
// engine.rs:43-48 — build dependency edges
for id in 0..n {
    if let Kind::NameRef { decl: Some(d), .. } = g.nodes[id].kind {
        g.nodes[id].dep = Some(d);       // NameRef → Name 声明
        g.nodes[d].dependents.push(id);  // 反向：声明 → 所有引用它的节点
    }
}
```

**父子边**在 `node.rs:369-377` 建立：`link_children()` 遍历所有节点的 `children_of()` 结果，为每个子节点设置 `parent: Some(parent_id)`。

### 2.3 核心变量：语义张力 T(v) → `State`

SOC 理论定义张力为 `T(v) = α·T_type + β·T_idiom + γ·T_effect + δ·T_interface + ε·T_verify`

kotlin2cj 的 `State` 结构体（`node.rs:311-317`）是这个概念的工程化简化版：

```rust
pub struct State {
    pub target: Option<String>,  // 当前译文（类似"译文已确定"标志）
    pub confidence: f32,         // 置信度 — 对应张力的倒数（高置信=低张力）
    pub version: u64,            // 版本号 — 每次变更递增，用于变更检测
    pub temperature: u32,        // 温度 — 触发次数计数，类似"应力累积"
}
```

关键映射：
- `target == None` → 节点尚未翻译（高张力）
- `target` 变更 → `version++`，`confidence = 1.0`，触发邻居级联
- `temperature` → 累积触发次数，对应"张力反复高位"的节点

当前版本**没有显式的 T_type / T_idiom / T_effect 分量**，而是通过以下方式隐式体现：
- **T_type** → `render()` 中的类型映射规则（`render.rs` 的 `render_call`、`render_member` 等）
- **T_idiom** → `render.rs` 中的惯用法选择（如 `.forEach` → `for` 循环、`?.let` → `if let`）
- **T_interface** → 依赖边传播——`step()` 中 `dependents` 入队（见下节）

---

## 三、动力学：崩塌规则 → `engine.rs`

### 3.1 规则 1（铺沙）→ `relax()` Phase 1

SOC 理论："初始时对全图执行最快速的直译，逐节点计算初始张力"

```rust
// engine.rs:102-111 — relax() Phase 1: 铺沙
pub fn relax(&mut self) {
    let n = self.g.nodes.len();
    let mut queue: VecDeque<NodeId> = (0..n).collect();  // 全图节点入队
    let mut avalanche = 0;
    while let Some(id) = queue.pop_front() {
        if self.step(id, &mut queue) {   // 逐节点应用局部规则
            avalanche += 1;
        }
    }
    self.last_avalanche = avalanche;
    // ...
}
```

"全图节点一次性入队"对应理论中"刻意铺得不均匀，张力高地自然显现"——每个节点各自独立渲染，但通过级联传播自动形成张力分布。

### 3.2 规则 2（崩塌）→ `step()` 中的 `render()` + `changed` 检测

SOC 理论："当 T(v) > θ（阈值），节点崩塌——触发一次局部重构"

```rust
// engine.rs:294-331 — step(): 崩塌与级联的核心
pub(crate) fn step(&mut self, id: NodeId, queue: &mut VecDeque<NodeId>) -> bool {
    let rendered = self.render(id);           // ← L1/L2/L3 算子：局部重构
    let new_target = match rendered {
        Some(t) => t,
        None => return false,                 // 无法渲染 = 低于阈值，不崩塌
    };
    self.g.nodes[id].state.temperature += 1;  // 温度递增（应力累积）

    let changed = self.g.nodes[id].state.target.as_deref() != Some(new_target.as_str());
    if changed {
        // 崩塌发生
        self.g.nodes[id].state.target = Some(new_target);
        self.g.nodes[id].state.version += 1;
        self.g.nodes[id].state.confidence = 1.0;
        self.total_updates += 1;

        // AMF: 记录雪崩记忆
        self.avalanche_memory[id] = self.avalanche_memory[id].saturating_add(1);

        // 规则 3: 张力再分配 → 父节点 + 依赖者 + 兄弟入队
        if let Some(p) = self.g.nodes[id].parent {
            queue.push_back(p);               // 自底向上传播
        }
        for d in self.g.nodes[id].dependents.clone() {
            queue.push_back(d);               // 沿依赖边传播（这是 δ·T_interface）
        }
        // 兄弟节点一致性
        if let Some(p) = self.g.nodes[id].parent {
            let siblings = self.g.children_of(p);
            for sib in siblings {
                if sib != id && self.g.nodes[sib].state.target.is_some() {
                    queue.push_back(sib);
                }
            }
        }
    }
    changed
}
```

**这里 `step()` 合并了规则 2 和规则 3**：
- `render(id)` → 局部重构（规则 2）
- `target` 变更后 push `parent` + `dependents` + `siblings` → 张力再分配（规则 3）

### 3.3 张力传导的传播方向

| 传导方向 | 代码实现 | SOC 对应 |
|---------|---------|---------|
| 子→父（自底向上） | `queue.push_back(p)` | 子节点译文变化，父节点需要重新组合 |
| 声明→引用（依赖边） | `dependents` 入队 | `T(u) ← T(u) + w(u,v)·Δ_interface(v)`，接口张力传导 |
| 兄弟→兄弟（横向） | `siblings` 入队 | 涌现一致性——如两个变量引用同一类型时统一表示 |

### 3.4 规则 4（慢驱动）→ `relax_soc()` 的 grain-by-grain

SOC 理论强调**慢驱动+快弛豫**的时间尺度分离。`relax_soc()` 实现了这个模式：

```rust
// engine.rs:177-240 — relax_soc(): 粒子驱动松弛
pub fn relax_soc(&mut self) -> Vec<usize> {
    // 收集叶子节点（无子节点的节点）作为「沙粒」
    let mut leaves: Vec<NodeId> = Vec::new();
    for id in 0..n {
        if self.g.children_of(id).is_empty() {
            leaves.push(id);
        }
    }

    // AMF + 深度双因素排序：低记忆优先、深层优先
    leaves.sort_by_key(|&id| {
        (self.avalanche_memory[id], std::cmp::Reverse(depth))
    });

    let mut grain_avalanches: Vec<usize> = Vec::new();
    for &leaf in &leaves {
        // 每粒沙：驱动一个叶子节点，等待级联完全平息
        let mut queue: VecDeque<NodeId> = VecDeque::new();
        queue.push_back(leaf);
        let mut avalanche = 0;
        while let Some(id) = queue.pop_front() {
            if self.step(id, &mut queue) {
                avalanche += 1;
            }
        }  // ← 级联完全结束后，才处理下一粒沙
        if avalanche > 0 {
            grain_avalanches.push(avalanche);  // 独立记录每次雪崩规模
        }
    }
    // ...
}
```

关键设计：
- **逐粒添沙**：`for &leaf in &leaves` —— 每粒沙触发完整雪崩后才添下一粒
- **独立雪崩记录**：`grain_avalanches` 存储每次雪崩规模，用于验证幂律分布
- **AMF 排序**：低记忆权重优先——"应力集中点"的叶子后处理，符合 SOC 的应力场长程记忆效应

### 3.5 批量模式 vs SOC 模式

`relax()` 的批量模式（所有节点一次性入队）vs `relax_soc()` 的 grain-by-grain 模式——这对应 `main.rs` 中的 `--soc-analysis` 选项（`main.rs:168-170`），用于对比两种模式的性能和时间。

---

## 四、重构算子库（L1/L2/L3）→ `render.rs`

SOC 理论将重构算子分三个层级。在 kotlin2cj 中，`render()` 函数（`render.rs:30`）的 2393 行代码就是**算子库**。

### 4.1 L1 局部算子（不改接口）

| SOC 理论 | render.rs 实现 |
|---------|---------------|
| 循环改迭代器 | `Kind::ForEach` → `for (v in iter) { }` |
| 裸指针解引用改安全访问 | N/A（Kotlin 无裸指针） |
| 错误码检查改 `?` 传播 | `Kind::Try` → `try-catch` 链，`Kind::Throw` → `throw` |
| 字面量映射 | `Kind::IntLit` → 直译, `Kind::CharLit` → `r'c'` |
| 简单二元运算 | `Kind::Binary { op, lhs, rhs }` → 中缀表达式 |

L1 算子的特点：只改节点自身的内容，不改变父节点的组合方式，**不传导张力**。

### 4.2 L2 接口算子（改变签名）

| SOC 理论 | render.rs 实现 |
|---------|---------------|
| 返回错误码 → `Result<T,E>` | `Kind::Func { ret, .. }` → 仓颉返回类型映射（通过 `stdlib_map.rs`） |
| 输出参数 → 返回元组 | N/A（Kotlin 无输出参数概念） |
| 回调参数 → 闭包 | `Kind::Lambda { params, body }` → `{ p => ... }` |

**`Kind::Name` 的 `original` 字段是最核心的 L2 算子载体**：

```rust
// node.rs:93-95
Kind::Name { original: String }
```

当 `Name` 节点的 `original` 被修改（如关键字转义 `fun` → `func`），所有指向它的 `NameRef` 节点（通过 `dependents`）自动入队重新渲染——这就是一次 L2 崩塌引发的雪崩。

### 4.3 L3 结构算子（改变拓扑）

当前版本主要通过以下方式实现：
- **`?.let` → `if let`+作用域重绑定**（`heuristics.rs:170-200` 的 `is_null_check_rebound()`）
- **`Kind::CollLit` → 集合字面量展开**（`render.rs:95-121`）
- **`Kind::Repeat` → `for` 循环**（`node.rs:145-149`）
- **类成员合并**：`Kind::Class` 的 `members` 展平 + `init_block` 合入构造器

### 4.4 算子选择策略

当前版本采用**确定性规则**（SOC 理论中的"三期原型"方式）：
- `render()` 通过 `match self.g.kind(id)` 分支选择，基于节点类型确定转换
- `heuristics.rs` 提供上下文感知信息（如 `is_null_check_rebound()`），影响 render 的选择
- 尚未实现 LLM 作为通用算子（第七节的愿景）

---

## 五、临界态为什么是"对的状态" → 未完成部分

SOC 第五节论述：
1. 雪崩规模分布的幂律指数作为收敛判据
2. 张力热图（绿/黄/红区）

**当前实现状态**：
- ✅ `avalanche_sizes: Vec<usize>` 收集了所有雪崩规模，**可以**用于事后分析（`engine.rs:23`）
- ✅ `avalanche_memory: Vec<u32>` 标记了高应力节点（`engine.rs:27`）
- ✅ `--soc-analysis` 模式输出雪崩分布 JSON（`main.rs:192-199`）
- ❌ 尚未自动判断幂律指数是否稳定（需要额外的统计工具）
- ❌ 尚未生成可视化的张力热图

`soc_analysis` 输出的三个关键指标（`main.rs:192-214`）：
```
SOC_GRAIN_AVALANCHES:3,1,7,2,...    ← 每次雪崩的规模
SOC_PERTURB_AVALANCHES:5,2,8,...    ← 全量扰动后的雪崩分布
SOC_NODES:N                         ← 图规模
```

---

## 六、完整算法流程 → `translate()` 函数

SOC 第六节的"一次铺沙 + 多轮慢驱动弛豫"对应 `main.rs` 的 `translate()` 和 `translate_soc()`：

```rust
// main.rs:22-28 — 标准流程（对应阶段 1+2）
fn translate(src: &str) -> Result<engine::Engine, String> {
    let toks = lexer::Lexer::new(src).tokenize()?;   // 阶段 0a: 词法分析
    let mut p = parser::Parser::new(toks);
    p.parse_program()?;                              // 阶段 0b: 建图
    let mut eng = engine::Engine::new(p.g);           // 阶段 0c: 建索引+依赖边
    eng.relax();                                      // 阶段 1: 铺沙 + 阶段 2: 弛豫
    Ok(eng)
}
```

`Engine::new()` 的阶段 0 工作（`engine.rs:40-95`）：
1. **建依赖边**：`NameRef.decl → Name` → `dep` + `dependents`
2. **建父子边**：`g.link_children()`
3. **建索引**：`decl_index`、`func_index`、`class_index`、`enum_index`

`relax()` 的弛豫流程（`engine.rs:102-118`）：
1. **Phase 1**：全图节点 worklist 迭代至收敛（铺沙+初始弛豫）
2. **Phase 2**：`context_refinement()` 自顶向下二次精化（退火）

`context_refinement()` (`engine.rs:127-163`) 实现了自顶向下的上下文传播：
- 按拓扑序（根→叶子）遍历
- 利用已稳定的父节点上下文重新评估子节点
- 对应 SOC 理论中"第二阶段自顶向下利用上下文精化"

**环节对照**：

| SOC 理论阶段 | 代码实现 |
|-------------|---------|
| 阶段 0: 建图与插桩 | `Engine::new()` — 依赖边、索引 |
| 阶段 1: 铺沙 | `relax()` Phase 1 — worklist 迭代 |
| 阶段 2: 弛豫主循环 | `relax_soc()` — grain-by-grain，`step()` 级联 |
| 阶段 3: 退火收尾 | `context_refinement()` — 自顶向下精化 |

---

## 七、与 LLM 的结合 → 当前实现策略

SOC 第七节提出 LLM 作为通用算子。当前版本采用**确定性规则替代 LLM**：
- `render.rs` 的 2393 行规则 = 手写的算子库
- `heuristics.rs` 的 977 行分析 = 自动生成"张力分解报告"（上下文感知的类型推断）
- 这正是第七节描述的：**SOC 框架决定何时、何地、以什么顺序调用算子**

`render.rs` 中的每个 `match` 分支本质上就是 L1/L2 算子，`heuristics.rs` 提供决策依据（类似张力分量的近似）。

### AMF（雪崩记忆反馈）

`engine.rs:8-10` 描述的 AMF 机制是当前实现中与 SOC 理论最精妙的对齐：

```rust
/// AMF（Avalanche Memory Feedback, AMF）：记录每个节点引发的级联规模，
/// 在后续松弛中优先评估高记忆权重节点的邻居，使系统自适应地集中计算资源于
/// 翻译困难区域——类似于真实 SOC 系统中应力场的长程记忆效应。
avalanche_memory: Vec<u32>,
```

`relax_soc()` 中按 `avalanche_memory` 升序排列叶子（`engine.rs:189-203`），低记忆优先：
- 第一次遍历：所有叶子记忆=0，按深度排序
- 如果某叶子触发大雪崩，其 `avalanche_memory` 增加
- 后续遍历：高记忆叶子后处理，给系统更多机会在低应力区稳定

---

## 八、走查一个雪崩 → `--demo-avalanche` 的实际行为

SOC 第八节描述了 C→Rust 的 config 全局结构体重构雪崩。

kotlin2cj 的 `--demo-avalanche` 选项（`main.rs:249-275`）演示了一个更简单但相同机理的场景：

```rust
// main.rs:249-275 — run_demo()
fn run_demo(eng: &mut engine::Engine) {
    // 1. 找一个有依赖者的 Name 节点
    let target = eng.g.nodes.iter()
        .find(|n| matches!(n.kind, Kind::Name { .. }) && !n.dependents.is_empty());

    // 2. 强制重命名该声明
    eng.perturb_rename(id, &format!("{}_renamed", old));

    // 3. 观察级联传播——所有引用该名称的 NameRef 节点
    //    通过 dependents 边自动入队，重新渲染，自动修复
    eprintln!("级联状态更新（雪崩规模）: {}", eng.last_avalanche);
}
```

`perturb_rename()` (`engine.rs:334-349`) 的流程：
1. 修改 `Name.original` → 清除 `target`（制造高张力）
2. 将该 Name 节点入队
3. `step()` 重新渲染它 → `changed=true` → `dependents` 全部入队
4. 每个 dependent（NameRef 节点）重新渲染，获取新名称
5. 级联沿依赖边传播直到平息

这正是 SOC 理论中 L2 算子（改名）触发雪崩的完整演示。

---

## 九、失效模式与对策 → 当前未覆盖但代码已预备

| SOC 理论对策 | 代码实现状态 |
|-------------|-------------|
| 振荡对策：疲劳计数 | `state.temperature` 可追踪重复触发次数（`engine.rs:300`），但尚未用于抑制振荡 |
| 张力标定：监督学习 | `confidence: f32` 字段已预留，目前固定为 `1.0` |
| 不收敛 → 红区标记 | `avalanche_memory` 可识别高应力节点，但未自动标注红区 |
| 增量测试 | 不在当前版本范围 |

---

## 十、可检验的预言 → 代码中的 SOC 测量

SOC 第十节提出三个可证伪的预言。代码提供了测量基础：

| 预言 | 代码支撑 |
|------|---------|
| 雪崩规模幂律分布 | `relax_soc()` 输出 `grain_avalanches`（`engine.rs:217`），`perturb_all_names()` 输出 `perturb_avals`（`engine.rs:247`） |
| 张力热图预测人工成本 | `avalanche_memory` + `temperature` 可直接生成热力图数据 |
| 消融实验（关掉张力传导） | 对比批量模式 `relax()` 的 `avalanche_sizes`（一次大雪崩）vs SOC 模式 `relax_soc()` 的 `grain_avalanches`（多段分布） |

`main.rs:176-245` 的 `run_soc_analysis()` 是这些测量的直接入口：
```
--soc-analysis  →  输出 SOC_GRAIN_AVALANCHES, SOC_PERTURB_AVALANCHES,
                    SOC_NODES, SOC_TOTAL_UPDATES, SOC_BULK_TIME_US,
                    SOC_SOC_TIME_US, SOC_OUTPUT_MATCH
```

---

## 总结：实现成熟度矩阵

| SOC 理论组件 | 实现状态 | 核心代码 |
|-------------|---------|---------|
| 语义依赖图 G=(V,E) | ✅ 已实现 | `node.rs` → `Graph`, `Node`, `Kind` |
| 调用边 (dep/dependents) | ✅ 已实现 | `engine.rs:42-48` |
| 数据流边 (parent/children) | ✅ 已实现 | `node.rs:369-377` |
| 效应边 | ❌ 未实现 | — |
| 张力场 T(v) | ⚠️ 简化版 | `node.rs:311-317` → `State` |
| 规则 1 铺沙 | ✅ 已实现 | `engine.rs:102-111` |
| 规则 2 崩塌 | ✅ 已实现 | `engine.rs:294-301` |
| 规则 3 张力再分配 | ✅ 已实现 | `engine.rs:311-328` |
| 规则 4 慢驱动 | ✅ 已实现 | `engine.rs:177-240` |
| L1 局部算子 | ✅ 已实现 | `render.rs` — 字面量、简单表达式 |
| L2 接口算子 | ✅ 已实现 | `render.rs` — Name 改名级联、类型映射 |
| L3 结构算子 | ⚠️ 部分实现 | `render.rs` — 类合并、?.let 重绑定 |
| AMF 雪崩记忆 | ✅ 已实现 | `engine.rs:27,307-309` |
| 上下文精化 (退火) | ✅ 已实现 | `engine.rs:127-163` |
| LLM 作为通用算子 | ❌ 未实现 | — |
| 幂律分布验证 | ⚠️ 数据已产出 | `grain_avalanches` 输出，需外部统计 |
| 张力热图 | ⚠️ 数据已具备 | `avalanche_memory` + `temperature` |

# 五大核心机制详解

> 用一段 Kotlin 代码从头跑到尾，解释 kotlin2cj 的五个 SOC 机制。

---

## 示例输入

```kotlin
fun greet(name: String): String {
    val msg = "Hello, " + name
    return msg
}

fun main() {
    val g = greet("World")
    println(g)
}
```

---

## 一、语义依赖图

### 概念

把整个程序拆成一堆**节点**，每个节点是一个"翻译单元"——一行文字、一个变量、一个函数调用。节点之间有两种连线：

- **父子边**（语法树）：`greet` 函数体下面的语句是它的孩子，语句里的表达式又是语句的孩子……
- **依赖边**（名称引用）：`return msg` 里的 `msg` 指向 `val msg = ...` 的声明；`greet("World")` 指向 `fun greet(...)` 的函数定义。

### 代码层面

```rust
// node.rs:319-331 — 每个节点长这样
pub struct Node {
    pub id: NodeId,
    pub kind: Kind,           // 什么类型：Func / VarDecl / NameRef / Call ...
    pub parent: Option<NodeId>,    // 父子边：谁包含我
    pub dep: Option<NodeId>,       // 依赖边：我引用了谁
    pub dependents: Vec<NodeId>,   // 反向依赖边：谁引用我
    pub state: State,              // SOC 状态（见下一节）
}
```

对示例代码，建图后大致是这样：

```
Program
├── Func "greet"  ──────────────────────────┐
│   ├── Param "name"                         │
│   ├── VarDecl "msg" ←──────────────────┐   │
│   │   ├── Name "msg"  ←── dep ─────────┤   │
│   │   └── Binary "+" (init)            │   │
│   └── Return ─── NameRef "msg" ──dep───┘   │
│                                            │
└── Func "main"                              │
    ├── VarDecl "g"                          │
    │   └── Call ─── NameRef "greet" ──dep───┘
    └── ExprStmt
        └── Call ─── NameRef "println"
```

依赖边在 `engine.rs:42-48` 建立：

```rust
// 遍历所有 NameRef 节点，找到它指向的声明 Name 节点，建立双向依赖
for id in 0..n {
    if let Kind::NameRef { decl: Some(d), .. } = g.nodes[id].kind {
        g.nodes[id].dep = Some(d);       // NameRef → Name
        g.nodes[d].dependents.push(id);  // Name → 所有引用它的 NameRef
    }
}
```

节点还携带一个 **State 向量**：

```rust
// node.rs:311-317
pub struct State {
    pub target: Option<String>,  // 本节点的当前译文（None = 还没翻译）
    pub confidence: f32,         // 置信度
    pub version: u64,            // 变更次数
    pub temperature: u32,        // 被触发次数（"应力"）
}
```

---

## 二、崩塌 + 张力传导

### 概念

"崩塌"是整个系统的核心动作。当一个节点被要求"重新计算自己的译文"，如果算出来的结果和之前不一样，它就**崩塌**——更新自己的 `target`，然后把"出事了"的信号沿边推给邻居。

传导方向有三条：

| 方向 | 含义 | 代码 |
|------|------|------|
| **自底向上**（子→父） | 我改了，包含我的父节点可能也需要重新拼装 | `queue.push_back(parent)` |
| **沿依赖边**（声明→引用） | 我的名称/签名变了，所有引用我的人都得重新翻译 | `dependents` 全部入队 |
| **横向**（兄弟→兄弟） | 同层兄弟之间共享上下文，一个变了可能影响另一个 | `siblings` 入队 |

### 代码层面

全部在 `engine.rs:293-331` 这个 `step()` 函数里：

```rust
pub(crate) fn step(&mut self, id: NodeId, queue: &mut VecDeque<NodeId>) -> bool {
    // 1. 对本节点执行局部渲染（应用翻译规则）
    let rendered = self.render(id);
    let new_target = rendered?;

    // 2. 应力累积：每被触发一次，temperature +1
    self.g.nodes[id].state.temperature += 1;

    // 3. 判断是否崩塌：新译文 != 旧译文？
    let changed = self.g.nodes[id].state.target.as_deref() != Some(new_target.as_str());

    if changed {
        // 崩塌！更新译文
        self.g.nodes[id].state.target = Some(new_target);
        self.g.nodes[id].state.version += 1;

        // ↓↓↓ 张力传导：三级传播 ↓↓↓

        // ① 自底向上：通知父节点
        if let Some(p) = self.g.nodes[id].parent {
            queue.push_back(p);
        }

        // ② 沿依赖边：通知所有引用我的人
        for d in self.g.nodes[id].dependents.clone() {
            queue.push_back(d);
        }

        // ③ 横向：通知兄弟节点
        if let Some(p) = self.g.nodes[id].parent {
            for sib in self.g.children_of(p) {
                if sib != id && self.g.nodes[sib].state.target.is_some() {
                    queue.push_back(sib);
                }
            }
        }
    }
    changed
}
```

### 以示例代码走一遍

假设所有节点初始 `target = None`。系统从叶子开始：

1. **`Name "msg"`**：`render()` 返回 `"msg"` → `target = Some("msg")`，changed=true
   - 传导：父节点 `VarDecl "msg"` 入队
   - 传导：dependents = [`NameRef "msg"`]（return 里的那个）入队

2. **`VarDecl "msg"`**：`render()` 组合出 `"let msg = \"Hello, \" + name"` → changed
   - 传导：父节点 `Func "greet"` 入队
   - 传导：兄弟节点（`Return`、`Binary` 等）入队

3. **`NameRef "msg"`**（return 里）：`render()` 读取 `dep` 指向的 Name 节点的 `target`，得到 `"msg"` → changed
   - 传导：父节点 `Return` 入队

4. 级联继续向上传播，直到 `Program` 节点的 `target` 稳定为最终译文。

整个过程中**没有一个中央调度器在指挥**——每个节点只知道自己和邻居，变化通过 `queue` 自动传播。

---

## 三、慢驱动（Grain-by-Grain）

### 概念

"慢驱动"的精髓是**时间尺度分离**：每次只扰动一个点（添一粒沙），等这粒沙引发的全部级联彻底平息后，再添下一粒。

为什么要这样？因为如果同时扰动多个点（像批量模式那样一次把所有节点入队），级联会互相交织干扰——A 的崩塌改了 B 的签名，B 又在同一时刻崩塌，互相不知道对方的最新状态。这就破坏了 SOC 理论中"串行弛豫"的纪律要求。

**类比**：往沙堆上添沙要一粒一粒加，不能一把撒。每粒沙落下去后引发的崩塌会自然传播完，沙堆恢复到稳定态，你才能加下一粒。

### 代码层面

```rust
// engine.rs:177-240
pub fn relax_soc(&mut self) -> Vec<usize> {
    // 1. 找出所有"叶子节点"（没有子节点的最底层节点）作为沙粒
    let mut leaves: Vec<NodeId> = Vec::new();
    for id in 0..n {
        if self.g.children_of(id).is_empty() {
            leaves.push(id);       // 叶子 = 字面量、Name、Raw 等原子节点
        }
    }

    // 2. 按 AMF 记忆权重 + 深度排序（见下一节）
    leaves.sort_by_key(|&id| (memory, Reverse(depth)));

    // 3. 逐粒添沙
    for &leaf in &leaves {
        let mut queue = VecDeque::new();
        queue.push_back(leaf);

        // 等这粒沙的雪崩彻底结束
        while let Some(id) = queue.pop_front() {
            if self.step(id, &mut queue) {
                avalanche += 1;
            }
        }
        // ← 雪崩平息，记录规模，然后才处理下一粒
        grain_avalanches.push(avalanche);
    }
}
```

关键对比——**批量模式 vs 慢驱动**：

| | 批量模式 `relax()` | 慢驱动 `relax_soc()` |
|---|---|---|
| 入队方式 | 全部节点一次性入队 | 每次只入队一个叶子 |
| 级联交叠 | 多个崩塌可能同时进行 | 一次雪崩完全平息后才开始下一个 |
| 雪崩记录 | 一条记录 | 每条雪崩独立记录 |
| 用途 | 普通翻译（快） | SOC 分析（观察幂律分布） |

### 遍历顺序也是精心设计的

先处理**深层叶子**（如字面量 `"Hello"`），再处理浅层叶子——因为深层的先稳定，浅层的（如函数名）后稳定，这样信息流是自底向上的，符合语法树的自然方向。

---

## 四、雪崩记忆（AMF）

### 概念

AMF = Avalanche Memory Feedback，雪崩记忆反馈。

真实沙堆里，那些经常发生大雪崩的斜坡位置会留下"印记"——坡面形态、颗粒排列都变了。下一次添沙到这里，系统会"记得"这是个危险位置。

翻译里完全一样：如果某个变量或函数每次被重命名都引发几十个引用者的连锁修改，说明它处于依赖图的**高扇出中心**。AMF 用一个数组记录每个节点历史上引发过多少次级联变更，然后在排序时利用这个记忆来调整驱动顺序。

### 代码层面

**记录**（每次状态变更时）：

```rust
// engine.rs:307-309
// AMF: 累积雪崩记忆
self.avalanche_memory[id] = self.avalanche_memory[id].saturating_add(1);
```

**利用**（决定叶子处理顺序时）：

```rust
// engine.rs:189-203
leaves.sort_by_key(|&id| {
    let memory = self.avalanche_memory[id];   // 第一排序键：记忆权重
    let depth = /* 计算节点深度 */;           // 第二排序键：深度
    (memory, Reverse(depth))                  // 低记忆优先，深层优先
});
```

**排序策略的含义**：

```
第一轮遍历（memory 全为 0）：
  叶子 A (深度 5) → 叶子 B (深度 5) → 叶子 C (深度 3) → ...

假设叶子 C 的渲染触发了 15 个节点的级联，memory[C] += 15。

第二轮遍历：
  叶子 A (memory=0) → 叶子 B (memory=0) → ...
  ...所有低记忆叶子处理完后，最后才处理 → 叶子 C (memory=15)
```

这模拟了真实 SOC 的**应力场长程记忆**：系统学会了"让容易引发大雪崩的区域先休息，等其他区域稳定后、系统有足够余量了，再去碰它"。

---

## 五、上下文精化

### 概念

前面的铺沙+慢驱动是**自底向上**的：叶子先稳定，逐层向上确定父节点。

上下文精化是一个**自顶向下**的补充：等第一遍全部稳定后，从根节点开始重新走一遍。这一次父节点已经有确定译文了，子节点可以利用父节点的上下文做出更准确的翻译选择。

### 为什么要做两遍

第一遍（自底向上）：子节点还不知道自己在哪里被使用。比如一个 `NameRef "msg"`，第一遍只知道自己引用了 `VarDecl "msg"`，把它翻译成 `msg`。

第二遍（自顶向下）：`VarDecl "msg"` 的父节点 `Func "greet"` 已经确定了返回类型是 `String`。子节点 `NameRef "msg"`（在 return 语句里）现在可以利用"我在一个返回 String 的函数里"这个上下文，做出更精确的选择——比如判断是否需要 `.toString()` 调用。

### 代码层面

```rust
// engine.rs:127-163
fn context_refinement(&mut self) {
    // 1. 按拓扑序（根→叶子）收集所有节点
    let mut topo = Vec::new();
    let mut stack = vec![self.g.root];    // 从根节点 Program 开始
    while let Some(id) = stack.pop() {
        topo.push(id);
        // 子节点入栈
        for &c in self.g.children_of(id).iter().rev() {
            stack.push(c);
        }
    }

    // 2. 自顶向下重新触发
    for &id in &topo {
        queue.push_back(id);   // 按根→叶顺序入队
    }
    while let Some(id) = queue.pop_front() {
        if self.step(id, &mut queue) {
            refinement_avalanche += 1;
        }
    }
}
```

第一遍遍历：叶子→根（深度优先出栈）
第二遍遍历：根→叶子（拓扑序）

### 一个具体例子

```kotlin
val x = someList.map { it * 2 }   // Kotlin 的 map
```

第一遍（自底向上）：
- Lambda 节点先被翻译成 `{ it => it * 2 }`
- `Call` 节点看到 `map`，但不知道接收者类型，保守翻译为方法调用
- 节点进入 "已翻译但不完全确定" 状态

第二遍（自顶向下）：
- `VarDecl` 节点已经知道 `x` 的上下文——可能后续被用作集合
- `heuristics.rs` 的 `looks_collection()` 函数回看 `map` 的接收者，判定它是集合
- 决定是否需要 `.toList()` 转换——`map` 在仓颉里返回的是迭代器

这就实现了 SOC 理论中描述的**"双向传播"——第一遍建立基础译文，第二遍利用上下文消歧**。

---

## 五个机制的协作全景

```
                    慢驱动（每次一粒沙）
                    ┌──────────────────┐
                    │ 叶子 1 → 雪崩 → 平息 │
                    │ 叶子 2 → 雪崩 → 平息 │
                    │ ...  AMF 排序 ...    │
                    │ 叶子 N → 雪崩 → 平息 │
                    └────────┬─────────┘
                             │
                    语义依赖图（节点+边）
                    ┌──────────────────┐
                    │  父 ←── 子        │  ← 语法边
                    │  声明 ←── 引用    │  ← 依赖边
                    │  兄弟 ←──→ 兄弟   │  ← 横向边
                    └────────┬─────────┘
                             │
                    step() 崩塌 + 张力传导
                    ┌──────────────────┐
                    │ render() → changed │
                    │  → push 父节点     │
                    │  → push 依赖者     │
                    │  → push 兄弟       │
                    │  → AMF 权重 +1     │
                    └────────┬─────────┘
                             │
                    上下文精化（自顶向下）
                    ┌──────────────────┐
                    │  根 → 叶子 重评估  │
                    │  利用已稳定上下文  │
                    │  消歧 + 打磨译文   │
                    └──────────────────┘
```

每个机制的独立性很强——你可以关掉 AMF 排序（退化为纯深度排序）、关掉横向传播（只剩父子+依赖两条传导边）、关掉上下文精化（只剩自底向上一次遍历），系统仍然能工作，只是译文质量和 SOC 统计数据会变化。这正是消融实验的设计基础。

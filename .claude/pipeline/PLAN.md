# k2cj-optimize Pipeline Plan

## 难度梯度设计

核心理念：**从翻译器自带测试 → ksoup 子包逐级扩大 → 中小型真实项目 → 大型硬骨头**。每级在上一级修复的基础上获得免费收益（G8 跨目标泛化），不重复造轮子。

```text
Phase 0         Phase 1 (混合小目标, <35 文件)                      Phase 2               Phase 3               Phase 4
(基线)          ksoup                     okhttp    ktor    koin    (⭐ 中型项目)           (⭐⭐⭐ 大型项目)        (⭐⭐⭐⭐⭐ 地狱)
─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
translator      1a exception (5)          ─         ─       ─      kotlinx-datetime       okhttp-full             kotlinx-serialization
own tests        1b safety+io (5)         ─         ─       ─      exposed                ktor-client             mockk
(187+33 ✅)      1c ─                     mock        ─       ─      koin-full              ksoup (221)             kotlinx-coroutines
                 1d parser (16)           ─         ─       ─                              arrow-core
                 1e ─                     ─         io (20)  ─
                 1f ─                     ─         ─      core(25)
                 1g ksoup-main (87)       ─         ─       ─
```

> Phase 1 覆盖 **4 个项目** 而不是 1 个——ksoup（HTML 解析）、okhttp（网络）、ktor（异步 I/O）、koin（依赖注入）。

### 为什么要这么设计

1. **Phase 0** — 翻译器自带的 187 单文件 + 33 工程测试，100% 通过。每次改翻译器后先跑这个，**1 分钟内确认无回归**。
2. **Phase 1** — 7 个小目标来自 **4 个不同项目**，每个 <35 文件（最后一个 87 是全量收口）。不是在一个项目上反复切子包，而是横跨 HTML 解析、网络 mock、异步 I/O、依赖注入四个领域——**强制翻译器适应不同代码风格，避免过拟合到 ksoup**。
3. **Phase 2** — 完整项目编译。datetime (~80)、koin (~120)、exposed (~150)。其中 datetime 和 koin 在 Phase 1 已有子模块经验，这里升级为全量。
4. **Phase 3** — 大型项目 + 硬语法（DSL 嵌套、suspend/callback、函数式抽象）。okhttp 和 ktor 在 Phase 1 已有子模块经验。
5. **Phase 4** — 最硬骨头：annotation processing、inline/reified、suspend/Flow。这些可能需要对翻译器做架构级改造（L3），放在最后。

## 候选目标详表

### Phase 0: 翻译器自身测试（基线门禁）

| 目标 | 规模 | 说明 | 难度 |
|------|------|------|:--:|
| **translator-own-tests** | 187 单文件 + 33 工程 | 翻译器自带的测试套件，每个文件测一个语法特性。**已全部通过（翻译+编译+运行）**，作为每次修改翻译器后的回归门禁。 | ⭐ |

### Phase 1: 混合小目标（来自 4 个不同项目）

> 每个目标 <35 文件，来源跨 4 个项目域：HTML 解析、网络、异步 I/O、依赖注入。
> 目标间按语法复杂度递增，同时强制翻译器适应不同代码风格。

| # | 目标 | 来源 | 规模 | 核心 Kotlin 特性 | 为什么这个顺序 |
|:--:|------|------|:---:|-----------------|---------------|
| 1a | **ksoup-exception** | ksoup | 5 | data class, enum, sealed class | 最轻入口——纯数据类，无算法逻辑 |
| 1b | **ksoup-safety+io** | ksoup | 5 | companion object, extension func, lambda | 少量逻辑 + 静态方法 |
| 1c | **okhttp-mockwebserver** | okhttp | ~30 | builder pattern, interceptor, MockResponse, coroutine | **第一个非 ksoup 项目**——网络 mock 场景，builder 链 + 回调用法 |
| 1d | **ksoup-parser** | ksoup | 16 | state machine, when expression, inline func | HTML 解析核心——回到 ksoup 但复杂度升级 |
| 1e | **ktor-io** | ktor | ~20 | ByteChannel, ByteReadPacket, coroutine I/O | **异步 I/O 领域**——测试 coroutine + 字节流模式 |
| 1f | **koin-core** | koin | ~25 | DSL, lazy delegate, module/qualifier, reified | **依赖注入领域**——测试 DSL + delegate + reified 组合 |
| 1g | **ksoup-main** | ksoup | 87 | 子包间交叉依赖、顶层声明、完整语法覆盖 | Phase 1 收官——ksoup 主模块 (`ksoup/ksoup/src/`) 全量，不含平台特定和多模块代码 |

> 1c/1e/1f 的模块由 Explorer agent 在运行时确认精确边界（取项目中最小的独立模块）

### Phase 2: 中等规模完整项目 (⭐⭐)

> 从 Phase 1 的"拆模块练手"升级到"完整项目编译"——这些项目 Phase 1 中已有子模块经验。

| 目标 | 规模 | 核心 Kotlin 特性 | 难度 | 为什么 Phase 2 而不是 Phase 1 |
|------|:---:|-----------------|:--:|---------|
| **kotlinx-datetime** | ~80 文件 | multiplatform, expect/actual, typealias, extension | ⭐⭐ | 多平台抽象——Phase 1 太小吃不饱，完整项目才能测跨平台翻译 |
| **koin** | ~120 文件 | DSL, lazy delegate, module definition, qualifier, scoping | ⭐⭐⭐ | Phase 1 只测了 core(25)，全量项目增加 scope + fragment + Android 适配 |
| **exposed** | ~150 文件 | type-safe SQL DSL, transaction, delegate property, infix | ⭐⭐⭐ | 全新项目——委托属性 + 运算符重载 + DSL 三合一 |

### Phase 3: 大型项目 + 硬语法 (⭐⭐⭐⭐)

| 目标 | 规模 | 核心 Kotlin 特性 | 难度 | 为什么选它 |
|------|------|-----------------|:--:|---------|
| **okhttp** | ~300 文件 | coroutine, interceptor chain, builder, TLS, WebSocket | ⭐⭐⭐⭐ | Phase 1 mockwebserver(~30) 升级到全量——网络层旗舰 |
| **ktor-client** | ~200 文件 | DSL, plugin pipeline, serialization, content negotiation | ⭐⭐⭐⭐ | Phase 1 ktor-io(~20) 升级到全量——DSL 极限压力测试 |
| **ksoup** | ~221 文件 | 多平台 (expect/actual), 多模块 (ksoup-io), 全语法覆盖 | ⭐⭐⭐⭐ | Phase 1 ksoup-main(87) 升级到真全量——多平台 + 多模块编译 |
| **arrow-core** | ~100 文件 | Either, Option, Validated, typeclass | ⭐⭐⭐⭐ | 函数式编程抽象 |

### Phase 4: 地狱难度 (⭐⭐⭐⭐⭐)

| 目标 | 规模 | 核心 Kotlin 特性 | 难度 | 为什么选它 |
|------|------|-----------------|:--:|---------|
| **kotlinx-serialization** | ~150 文件 | annotation processing, KSP, reified, inline class | ⭐⭐⭐⭐⭐ | 编译期代码生成 + 注解处理器——仓颉无直接对应物 |
| **mockk** | ~100 文件 | mock, inline, reified, reflection | ⭐⭐⭐⭐⭐ | 最硬骨头——inline/reified 在仓颉中无直接对应 |
| **kotlinx-coroutines** | ~200 文件 | suspend, CoroutineScope, Flow, Channel, actor | ⭐⭐⭐⭐⭐ | 协程→仓颉无对应，需 L3 级架构决策 |

## ksoup 全项目规模

> 仅 `ksoup/ksoup/src/`（主模块公共源码）= 87 文件。全项目分布：

```
ksoup/ksoup/src/          87  ← Phase 1g: ksoup-main
ksoup/ksoup/src@jvm/      13  ← 平台特定 (Platform.jvm.kt 等)
ksoup/ksoup/src@mingw/     8  ← 平台特定
ksoup/ksoup-io/            9  ← 独立 I/O 模块
ksoup/ksoup-benchmark/     1  ← 性能测试
─────────────────────────────
全量合计:                 ~118 文件 (不含 benchmark)
                          ~221 文件 (含所有源码集)
```

> 真正全量 ksoup (~221 文件) 留在 Phase 3 作为大型多模块项目处理。

## ksoup-main 子包文件清单

> Phase 1 用到 exception、safety、io、parser 四个子包，外加 ksoup-main。其他子包（select、internal、ported、nodes）不单独翻译，包含在全量 ksoup-main 中。

```
ksoup/ksoup/src/com/fleeksoft/ksoup/
├── exception/    5 files — HttpStatusException, CharsetSwitchException, ...
├── io/           3 files — KsoupIO, StreamParser, ...
├── safety/       2 files — Safelist, Whitelist
├── parser/      16 files — HtmlParser, Tokeniser, TokenQueue, CharacterReader, ...
├── select/      12 files — (包含在 ksoup-main 中)
├── internal/     8 files — (包含在 ksoup-main 中)
├── ported/      14 files — (包含在 ksoup-main 中)
├── nodes/       21 files — (包含在 ksoup-main 中)
├── helper/       1 file  — (包含在 ksoup-main 中)
└── model/        1 file  — (包含在 ksoup-main 中)
```

## 收敛判定

- **G1**: 0 编译错误
- **G10**: x2cj-eval ≥ 75（仅 Phase 2+ 项目需要，Phase 0/1 只需 G1）
- 两者都满足 → 标记 ✅ 收敛，自动切到下一个目标
- **Phase 0/1 特殊规则**：只需 0 errors，不需要 x2cj-eval（子包没有独立运行标准）

## 卡住判定

- 连续 **2 轮**无错误数量减少 → 标记 **STUCK**，自动切换目标
- STUCK 的目标进入「观察列表」，等翻译器有重大升级（如 L2/L3 级修复）后重新解锁

## 运行方式

### 手动（指定目标）
```bash
/goal "k2cj-optimize target=translator-own-tests"
/goal "k2cj-optimize target=ksoup-exception"
```

### 定时轮换（多目标）
```bash
hermes cron create \
  --schedule "0 */4 * * *" \
  --prompt "/goal 'k2cj-optimize target=round_robin'" \
  --workdir /home/songy/SunriseSummer-X2Cangjie
```

### 当前目标分配合逻辑
优先取当前 ⏳ (in-progress) 状态的目标。若当前目标 ✅ 收敛，按 Phase 顺序取下一个 🔒 目标：

```
Phase 0: translator-own-tests
Phase 1: ksoup-exception → ksoup-safety+io → okhttp-mockwebserver → ksoup-parser → ktor-io → koin-core → ksoup-main
Phase 2: kotlinx-datetime → koin → exposed
Phase 3: okhttp → ktor-client → ksoup → arrow-core
Phase 4: kotlinx-serialization → mockk → kotlinx-coroutines
```

## 架构融合标记

| 维度 | 架构来源 | 本系统实现 |
|------|---------|-----------|
| 知识组织 | **B** | `.claude/skills/` + `.claude/agents/` — 声明式配置 |
| 质量控制 | **B** | `.claude/guards/` — 每阶段显式门禁 |
| 时间循环 | **C** | `/goal` + cron — 自动反复跑到收敛 |
| 并行隔离 | **C** | `git worktree` — 多个 fix 不冲突 |
| 持久状态 | **C** | `state/optimization-state.md` — 跨 run 跨目标记忆 |
| 制造/检查分离 | **C** | fixer（制造）≠ verifier（检查），不同 agent |
| SOC 理论 | **自有** | 张力=编译错误数，级联=依赖模块重编译，慢驱动=逐错误修复 |

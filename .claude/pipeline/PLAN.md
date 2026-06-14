# k2cj-optimize Pipeline Plan

## 当前目标

| 属性 | 值 |
|------|-----|
| 目标代码库 | `$TARGET` — 由 `/goal "k2cj-optimize target=<name>"` 或 explorer 发现 |
| 源路径 | 待 explorer 确认（支持本地路径、Git URL、GitHub org/repo） |
| 翻译器分支 | `ksoup-entities-validation-2-2`（主开发分支） |
| 优化目标 | `cjpm build` 0 errors |

### 切换目标

```bash
# 方式 1: 直接指定
/goal "k2cj-optimize target=okhttp"

# 方式 2: 让 explorer 发现候选
/goal "k2cj-optimize discover"  # explorer 扫描并推荐

# 方式 3: 定时轮换多个目标
cron --prompt "/goal 'k2cj-optimize target=round_robin'" --schedule "0 */8 * * *"
```

### 候选目标库

| 目标 | 规模 | 核心 Kotlin 特性 | 难度 | 为什么选它 |
|------|------|-----------------|:--:|---------|
| **ksoup** | ~120 文件 | data class, companion, sealed, extension, inline func, annotation | ⭐⭐⭐ | HTML parser，语法覆盖均衡，已有翻译历史 |
| **okhttp** | ~300 文件 | coroutine, interceptor chain, builder, TLS, WebSocket | ⭐⭐⭐⭐ | 网络层旗舰，suspend/callback/流式处理全覆盖 |
| **ktor-client** | ~200 文件 | DSL, plugin pipeline, serialization, content negotiation | ⭐⭐⭐⭐ | DSL 密集型——极限测试 parser 的嵌套表达能力 |
| **kotlinx-serialization** | ~150 文件 | annotation processing, KSP, reified, inline class | ⭐⭐⭐⭐⭐ | 编译期代码生成 + 注解处理器——仓颉无直接对应物 |
| **exposed** | ~150 文件 | type-safe SQL DSL, transaction, delegate property, infix | ⭐⭐⭐ | 委托属性 + 运算符重载 + DSL 三合一 |
| **mockk** | ~100 文件 | mock, inline, reified, reflection, relaxed mock | ⭐⭐⭐⭐⭐ | 最硬骨头——inline/reified 在仓颉中无直接对应 |
| **kotlinx-coroutines** | ~200 文件 | suspend, CoroutineScope, Flow, Channel, actor | ⭐⭐⭐⭐⭐ | 协程→仓颉无对应，需 L3 级架构决策（相当于 SOC 的 C→Rust 全局状态问题） |
| **kotlinx-datetime** | ~80 文件 | multiplatform, expect/actual, typealias, extension | ⭐⭐⭐ | 多平台声明 + 类型别名，测试跨平台抽象翻译 |
| **koin** | ~120 文件 | DSL, lazy delegate, module definition, qualifier | ⭐⭐⭐ | 依赖注入 DSL——测试 DSL + 委托的组合 |
| **arrow-core** | ~100 文件 | Either, Option, Validated, extension, infix, typeclass | ⭐⭐⭐⭐ | 函数式编程抽象——Either/Option→仓颉 enum 的映射压力测试 |

### 难度梯度设计

```
⭐⭐⭐         ⭐⭐⭐⭐              ⭐⭐⭐⭐⭐
ksoup        okhttp              kotlinx-serialization
exposed      ktor-client         mockk
koin         arrow-core          kotlinx-coroutines
datetime
```

从易到难逐步推进，和 SOC 慢驱动一致——不在一个目标上过度投资。
也对应 G8（跨目标泛化）的验证需求：在 ⭐⭐⭐ 级目标上修的 bug，看对 ⭐⭐⭐⭐ 级是否也有效。

## 阶段状态

| Stage | Agent | Guard | 状态 | 备注 |
|-------|-------|-------|------|------|
| 1. Explore | k2cj-explorer | 1-explore-guard.md | ⏳ | 确认 `$TARGET` 路径 |
| 2. Translate | k2cj-translator | 2-translate-guard.md | ⏳ | |
| 3. Compile | (内置) | 3-compile-guard.md | ⏳ | `cjpm build` |
| 4. Diagnose | k2cj-diagnostician | 4-diagnose-guard.md | ⏳ | 错误分类 |
| 5. Fix | k2cj-fixer | 5-fix-guard.md | ⏳ | worktree 修复 |
| 6. Verify | k2cj-verifier | 6-verify-guard.md | ⏳ | 全量回归 |

## Active Blockers

（当前无）

## 运行方式

### 一次性（指定目标）

```
/goal "k2cj-optimize target=ktor-client"
```

### 一次性（explorer 自动发现）

```
/goal "k2cj-optimize discover"
```

### 定时循环（单一目标）

```bash
hermes cron create \
  --schedule "0 */4 * * *" \
  --prompt "/goal 'k2cj-optimize target=ksoup'" \
  --workdir /home/songy/SunriseSummer-X2Cangjie
```

### 定时轮换（多目标）

```bash
hermes cron create \
  --schedule "0 */8 * * *" \
  --prompt "/goal 'k2cj-optimize target=round_robin'" \
  --workdir /home/songy/SunriseSummer-X2Cangjie
```
> round_robin 模式：读 `state/optimization-state.md` 中的目标轮换表，取下一个待优化的目标，跑一轮后更新轮换表。

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

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

| 目标 | 文件数 | Kotlin 特性覆盖 | 难度 | 状态 |
|------|--------|----------------|------|------|
| ksoup | ~120 | data class, companion, sealed, extension, inline | ⭐⭐⭐ | 当前 |
| okhttp | ~300 | coroutine, interceptor, builder pattern, annotation | ⭐⭐⭐⭐ | 候选 |
| ktor-client | ~200 | DSL, plugin, coroutine, serialization | ⭐⭐⭐⭐ | 候选 |
| exposed | ~150 | DSL, type-safe SQL, transaction, delegate | ⭐⭐⭐ | 候选 |
| mockk | ~100 | DSL, mock, inline, reified, reflection | ⭐⭐⭐⭐⭐ | 候选 |

> Explorer agent 启动时会自动扫描以上目标，确认可编译性和路径。新增目标加到上表即可。

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

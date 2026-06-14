# k2cj-optimize Pipeline Plan

## 当前目标

| 属性 | 值 |
|------|-----|
| 目标代码库 | ksoup（Kotlin HTML parser） |
| 源路径 | 待 explorer 确认 |
| 翻译器分支 | `ksoup-entities-validation-2-2` |
| 优化目标 | `cjpm build` 0 errors |

## 阶段状态

| Stage | Agent | Guard | 状态 | 剩余工作 |
|-------|-------|-------|------|---------|
| 1. Explore | k2cj-explorer | 1-explore-guard.md | ⏳ | 确认 ksoup 路径 |
| 2. Translate | k2cj-translator | 2-translate-guard.md | ⏳ | — |
| 3. Compile | (内置) | 3-compile-guard.md | ⏳ | — |
| 4. Diagnose | k2cj-diagnostician | 4-diagnose-guard.md | ⏳ | — |
| 5. Fix | k2cj-fixer | 5-fix-guard.md | ⏳ | — |
| 6. Verify | k2cj-verifier | 6-verify-guard.md | ⏳ | — |

## Active Blockers

（当前无）

## 运行方式

### 一次性运行

```
/goal "kotlin2cj 翻译 ksoup 并通过编译，必要时自动修复翻译器"
```

### 定时循环

```bash
# 每 4 小时
hermes cron create \
  --schedule "0 */4 * * *" \
  --prompt "/goal 'k2cj-optimize target=ksoup'" \
  --workdir /home/songy/SunriseSummer-X2Cangjie
```

### 手动触发单次

```
使用 k2cj-optimize skill，对 ksoup 跑一轮优化
```

## 架构融合标记

| 维度 | 架构来源 | 本系统实现 |
|------|---------|-----------|
| 知识组织 | **B** | `.claude/skills/` + `.claude/agents/` — 声明式配置 |
| 质量控制 | **B** | `.claude/guards/` — 每阶段显式门禁 |
| 时间循环 | **C** | `/goal` + cron — 自动反复跑到收敛 |
| 并行隔离 | **C** | `git worktree` — 多个 fix 不冲突 |
| 持久状态 | **C** | `state/optimization-state.md` — 跨 run 记忆 |
| 制造/检查分离 | **C** | fixer（制造）≠ verifier（检查），不同 agent |
| SOC 理论 | **自有** | 张力=编译错误数，级联=依赖模块重编译，慢驱动=逐错误修复 |

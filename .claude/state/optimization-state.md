# kotlin2cj 优化状态

> 跨 run 持久化。每轮 fixer 追加，orchestrator 启动时先读。
>
> 难度梯度：Phase 0 (⭐ 基线) → Phase 1 (混合小目标, 4 项目) → Phase 2 (⭐⭐) → Phase 3 (⭐⭐⭐⭐) → Phase 4 (⭐⭐⭐⭐⭐)

---

## 全局进度

```
Phase 0       Phase 1                          Phase 2       Phase 3       Phase 4
[✅]          [ ][ ][ ][ ][ ][ ][ ]            [ ][ ][ ]     [ ][ ][ ]     [ ][ ][ ]
```

---

## Phase 0: 翻译器自身测试 (基线)

| 目标 | 测试规模 | 状态 | 备注 |
|------|---------|:--:|------|
| translator-own-tests | 187 single + 33 project | ✅ | 全通过。作为回归门禁 |

---

## Phase 1: 混合小目标（来自 4 个项目）

| # | 目标 | 来源 | 文件数 | 状态 | 编译错误 | 核心特性 |
|:--:|------|------|:---:|:--:|:-------:|---------|
| 1a | ksoup-exception | ksoup | 5 | 🔒 | - | data class, sealed, enum |
| 1b | ksoup-safety+io | ksoup | 5 | 🔒 | - | companion, extension, lambda |
| 1c | okhttp-mockwebserver | okhttp | ~30 | 🔒 | - | builder, interceptor, coroutine |
| 1d | ksoup-parser | ksoup | 16 | 🔒 | - | state machine, when, inline |
| 1e | ktor-io | ktor | ~20 | 🔒 | - | ByteChannel, coroutine I/O |
| 1f | koin-core | koin | ~25 | 🔒 | - | DSL, delegate, reified |
| 1g | ksoup-main | ksoup | 87 | 🔒 | - | 全量交叉编译 |

> ⏳ = in-progress, 🔒 = locked, ✅ = converged, 🟡 = blocked, ❌ = stuck

---

## Phase 2: 中等规模完整项目

| 目标 | 规模 | 状态 | 编译错误 | x2cj-eval | 备注 |
|------|:---:|:--:|:-------:|:---------:|------|
| kotlinx-datetime | ~80 | 🔒 | - | - | Phase 1 无子模块，全新完整项目 |
| koin | ~120 | 🔒 | - | - | Phase 1 测过 core(25)，升级全量 |
| exposed | ~150 | 🔒 | - | - | 全新项目 |

---

## Phase 3: 大型项目 + 硬语法

| 目标 | 规模 | 状态 | 编译错误 | x2cj-eval | 备注 |
|------|:---:|:--:|:-------:|:---------:|------|
| okhttp | ~300 | 🔒 | - | - | Phase 1 测过 mockwebserver(~30) |
| ktor-client | ~200 | 🔒 | - | - | Phase 1 测过 ktor-io(~20) |
| ksoup | ~221 | 🔒 | - | - | Phase 1 测过 ksoup-main(87)，升级真全量 |
| arrow-core | ~100 | 🔒 | - | - | 全新项目 |

---

## Phase 4: 地狱难度

| 目标 | 规模 | 状态 | 编译错误 | x2cj-eval | 备注 |
|------|:---:|:--:|:-------:|:---------:|------|
| kotlinx-serialization | ~150 | 🔒 | - | - | |
| mockk | ~100 | 🔒 | - | - | |
| kotlinx-coroutines | ~200 | 🔒 | - | - | |

---

## 历史记录

### ksoup R0 (2025-06-14) — 已存档

- **997 编译错误** → 单根因：var-func 命名冲突
- 修复：`engine.rs` `resolve_var_func_collisions()`
- 翻译器版本：分支 `ksoup-entities-validation-2-2`

### ksoup R1 (2025-06-15) — 已存档

- error 从 997 → 23（97.7% 减少），87/87 文件翻译成功
- 剩余 23 错误：unicode surrogates / ::class 引用 / ::add / let 缺类型 / bare companion / keys()
- 鉴于难度梯度重新设计，ksoup 拆为子包 + 混合跨项目目标重新开始

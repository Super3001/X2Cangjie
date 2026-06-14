# G10 语义保持 — 编译通过 ≠ 翻译正确

## 定义

**编译通过**只是证明了翻译产物是合法的仓颉程序。**语义保持**证明它和源 Kotlin 程序做的是同一件事。

## 为什么必不可少

```
┌─────────────┐    kotlin2cj    ┌──────────────┐
│  Kotlin 源码 │ ──────────────→ │ 仓颉翻译产物  │
│  fun add(a,b)│                │ func add(a,b) │
│  = a + b    │                │ = a - b    ←── 编译通过！语义错误！
└─────────────┘                └──────────────┘
```

SOC 理论中这是 **T_verify** — 验证张力分量。没有它，系统可能在"0 compile errors"处停在一个**语义错误但语法正确**的亚稳态。

## 测量方式

### 方式 A：差分测试（x2cj-test 已验证的模式）

```
源 Kotlin 测试 ──编译──→ 运行 ──→ 输出 A
       │
       │ x2cj 翻译
       ▼
仓颉测试 ──编译──→ 运行 ──→ 输出 B
                            │
                     A == B ? ──→ YES: PASS
                            ──→ NO: 语义漂移 → 回 diagnoser
```

### 方式 B：属性测试（无测试套件时）

对翻译产物生成随机输入，对比源程序和翻译产物的输出。

### 方式 C：静态分析（编译时就发现的语义问题）

- Kotlin `Int` (32-bit) → 仓颉 `Int64` (64-bit)：溢出行为不同
- Kotlin `Char` (UTF-16 code unit) → 仓颉 `Rune` (Unicode scalar)：surrogate pair 处理不同
- Kotlin `==` (structural) / `===` (referential) → 仓颉统一的 `==`

## 阶段设计

在 Stage 3 (Compile) 和 Stage 4 (Diagnose) 之间插入 Stage 3.5：

```
Stage 3: Compile ──0 errors──→ Stage 3.5: Semantic Verify
                                       │
                          ┌────────────┼────────────┐
                          │            │            │
                     有测试套件    无测试套件    静态语义差异
                          │            │            │
                     差分测试      属性测试      T_type 计入
                          │            │            │
                     PASS/FAIL    PASS/FAIL      WARNING
                          │            │            │
                          └────────────┼────────────┘
                                       │
                                 0 diff ──→ 🎉 真正收敛
                                >0 diff ──→ Stage 4 诊断
```

## Guard: 3.5-semantic-guard.md

```
PASS: 所有差分测试通过 OR 属性测试无反例
FIX: 差分测试失败 → 语义漂移，最高优先级修复
SKIP: 目标无测试套件且无法自动生成属性测试 → 标记为 WARNING，不阻塞
```

## 外部知识依赖

x2cj-test 系统已实现差分测试全流程：
- `~/x2cj/skills/x2cj-test/SKILL.md` — 差分测试工作流
- Java `mvn test` → 输出
- `x2cj` 翻译 Java 测试 → 仓颉测试
- `cjpm test` → 对比输出

kotlin2cj 可复用同一套逻辑，只需将 Java→Kotlin 的测试生成替换为：直接用目标 Kotlin 项目的已有测试。

## 对收敛判据的影响

```
之前: cjpm build 0 errors → 收敛
之后: cjpm build 0 errors + 语义验证 0 diff → 真正收敛
```

**语义漂移但编译通过**是比编译错误更危险的失败模式——它不会阻塞 pipeline，但会产出"看起来对其实是错的"翻译。

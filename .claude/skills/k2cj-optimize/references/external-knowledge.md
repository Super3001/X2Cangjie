# 外部知识导入规范

> 统一定义 kotlin2cj 和 x2cj-test 两个项目各自从 x2cj-skills 加载什么知识、以什么顺序加载。
> 本文件放在 SunriseSummer-X2Cangjie 仓库，供两个项目的 agent 共同遵守。

---

## 一、知识源（x2cj-skills 提供）

所有外部知识来自 `~/x2cj-skills/`，按类别三层：

### 翻译规则（已验证的 Java→Cangjie 映射）

| 路径 | 内容 | 行数 |
|------|------|:--:|
| `skills/x2cj/rules/docs/basic/syntax.md` | 类型映射、关键字转义、lambda | 255 |
| `skills/x2cj/rules/docs/io/*.md` | Stream/Reader/Writer/序列化 | 18 文件 |
| `skills/x2cj/rules/docs/thread/*.md` | 线程/ThreadLocal | 2 文件 |
| `skills/x2cj/rules/docs/android/*.md` | Android API 映射 | 多文件 |
| `skills/x2cj/rules/docs/logging/` | 日志 | 1 文件 |
| `skills/x2cj/rules/docs/uuid/` | UUID | 1 文件 |
| `skills/x2cj/rules/tpc-dependency-mapping.md` | TPC 依赖映射 | — |
| `skills/x2cj/rules/code-style.md` | 代码风格 | — |

### 仓颉语言参考

| 路径 | 内容 |
|------|------|
| `skills/cangjie-dev/SKILL.md` | 仓颉开发总入口 |
| 其下子文档 | 语法特性、标准库、扩展库、工具链 |

### 评估标准

| 路径 | 内容 |
|------|------|
| `skills/x2cj-eval/skill.md` | LLM 语义评估流程 + prompt 模板（14 子维度） |

---

## 二、各项目加载声明

### kotlin2cj 优化系统

**加载者**：k2cj-diagnostician、k2cj-fixer、k2cj-verifier

**加载顺序**：

```
1. kotlin-cangjie-patterns.md     ← 项目私有：Kotlin→Cangjie 已知模式（本项目特有）
2. fix-history.md                 ← 项目私有：历次修复记录（避免重复）
3. x2cj rules (syntax > io > ...) ← 外部：Java→Cangjie 规则（Kotlin 和 Java 共享 JVM 生态）
4. cangjie-dev 语言参考            ← 外部：确认仓颉 API 合法性
5. x2cj-eval                      ← 外部：语义评估标准（G10 判据）
```

> Kotlin 和 Java 共享 JVM 类型系统和大量 API——x2cj 的 Java 规则对 Kotlin 翻译直接适用。

### x2cj-test 验证系统

**加载者**：x2cj-test orchestrator、review-agent、gate-agent

**加载顺序**：

```
1. x2cj rules (syntax > io > ...) ← 外部：Java→Cangjie 规则（验证翻译是否遵循已知规则）
2. cangjie-dev 语言参考            ← 外部：确认仓颉侧的 API/语法是否正确
3. x2cj-eval                      ← 外部：语义评估标准（Stage 2 入口门禁）
```

> x2cj-test 不需要项目私有知识——它是通用验证系统，不绑定特定源语言的项目模式。

---

## 三、加载规则

### 时机

- **diagnostician / fixer**：每次被调用时加载（任务之间上下文不共享）
- **verifier / reviewer**：语义评估阶段加载
- **gate-agent**：执行 guard 检查前按需加载（如 Stage 2 guard 需要 x2cj-eval 的评分标准）

### 顺序原则

```
便宜先查 → 贵后问
   │           │
   │      ┌────┴────┐
   │      │         │
本地文件  已有规则   LLM自由裁量
（0 token）（已有答案）（需要推理）
```

1. 先查本地私有知识（已有答案，不走 LLM）
2. 再查外部规则（已验证映射，有文档依据）
3. 再查语言参考（确认语法/API 合法性）
4. 最后查评估标准（判断"对不对"的依据）
5. 以上都不确定时，才让 LLM 自行判断

### 不做的事

- ❌ agent 不跨项目加载对方的私有知识
- ❌ 不把规则文档全文塞进 prompt（只查相关条目）
- ❌ 不在对话 context 里记知识查询结果（查完就用，不缓存到 context）

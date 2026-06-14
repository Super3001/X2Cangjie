# 外部知识导入清单

k2cj-optimize 的 agent 在执行任务前，应加载以下外部知识源：

## 仓颉语言知识（仓库内 `.github/skills/`）

| Skill | 路径 | 何时加载 | 加载者 |
|-------|------|---------|--------|
| cangjie-lang-features | `.github/skills/cangjie-lang-features/SKILL.md` | 仓颉语法特性不确定时 | fixer, diagnostician |
| cangjie-std | `.github/skills/cangjie-std/SKILL.md` | 标准库函数映射不确定时 | fixer, translator |
| cangjie-stdx | `.github/skills/cangjie-stdx/SKILL.md` | 扩展标准库映射不确定时 | fixer |
| cangjie-regulations | `.github/skills/cangjie-regulations/SKILL.md` | 编码规范/项目结构不确定时 | fixer |
| cangjie-toolchains | `.github/skills/cangjie-toolchains/SKILL.md` | cjpm build/test 命令不确定时 | translator, verifier |
| cangjie-original-docs | `.github/skills/cangjie-original-docs/SKILL.md` | 深度语言特性查阅时 | diagnostician |

## Java→Cangjie 已验证翻译规则（`~/x2cj-skills/skills/x2cj/rules/`）

| 领域 | 路径 | 何时加载 | 加载者 |
|------|------|---------|--------|
| basic/syntax | `rules/docs/basic/syntax.md` (255行) | 类型映射、关键字转义、lambda | fixer, diagnoser |
| IO | `rules/docs/io/*.md` (18个文件) | Stream/Reader/Writer/序列化映射 | fixer |
| thread | `rules/docs/thread/*.md` | 线程/ThreadLocal 映射 | fixer |
| android | `rules/docs/android/*.md` | Android API 映射（目标含 Android 时） | fixer |
| logging/uuid | `rules/docs/logging/`, `rules/docs/uuid/` | 工具类映射 | fixer |

> 这些规则是 **Java→Cangjie** 的，但对 Kotlin→Cangjie 直接适用——Kotlin 和 Java 共享 JVM 类型系统、集合框架、IO API。fixer 在遇到类型映射不确定时优先查 x2cj rules，它包含了已验证的 `Int→Int64`、`byte→Int8`、`Object→Any` 等映射。

## 差分测试设施（`~/x2cj/skills/x2cj-test/`）

| 资产 | 路径 | 何时加载 | 加载者 |
|------|------|---------|--------|
| SKILL.md | `skills/x2cj-test/SKILL.md` | 语义验证阶段 | verifier |
| output-schema | `skills/x2cj-test/references/output-schema.json` | 语义验证输出格式 | verifier |
| Java env setup | `skills/x2cj-test/references/env-setup-java.md` | 准备 Java 测试环境 | verifier |
| Cangjie env setup | `skills/x2cj-test/references/env-setup-cangjie.md` | 准备仓颉测试环境 | verifier |

> x2cj-test 已实现完整的差分测试流水线：Java 跑测试 → 翻译测试 → 仓颉跑测试 → 对比输出。kotlin2cj 的语义验证直接复用这套设施，只需将 `x2cj` 翻译步骤替换为 `kotlin2cj`。

## 翻译模式知识（本 skill 内）

| 文件 | 路径 | 何时加载 | 加载者 |
|------|------|---------|--------|
| kotlin-cangjie-patterns.md | `references/kotlin-cangjie-patterns.md` | 每次诊断/修复前 | diagnostician, fixer |
| fix-history.md | `references/fix-history.md` | 每次修复前（避免重复） | fixer |

## 加载规则

1. **diagnostician 启动时**：加载 `cangjie-std` + `cangjie-lang-features` + `kotlin-cangjie-patterns.md`
2. **fixer 启动时**：加载 `kotlin-cangjie-patterns.md` + `fix-history.md` + 按需加载仓颉 skill
3. **translator 启动时**：加载 `cangjie-toolchains`（确认 cjpm 命令）
4. **verifier 启动时**：加载 `cangjie-toolchains`（确认测试命令）

## 外部知识扩展

当遇到新模式时，fixer 应在提交修复的同时：
1. 追加条目到 `kotlin-cangjie-patterns.md`
2. 追加条目到 `fix-history.md`

这形成了 **知识的复利**：每次修复不仅解决当前问题，还丰富了后续 agent 的决策依据。

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

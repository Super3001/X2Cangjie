# AI Team — kotlin2cj 优化系统

## 触发

- "优化 kotlin2cj"
- "翻译 ksoup 并修复"
- "跑优化循环"
- `/goal "k2cj-optimize target=<name>"`

## 关键规则

- **Orchestrator 只调度，不执行代码** — 所有修改由 fixer agent 在 worktree 中完成
- **每个阶段必经 Gate Agent 验收** — 不通过不进下一阶段
- **State 是唯一真相源** — 读 `state/optimization-state.md` 获取进度，不依赖 context 记忆
- **回归即回退** — 任何已有测试失败 → 丢弃 worktree，重试
- **L1 优先** — 先尝试单文件小改，失败了再升级到 L2/L3 多文件改动

## Agent 团队

| Agent | 文件 | 职责 |
|-------|------|------|
| k2cj-orchestrator | `agents/k2cj-orchestrator.md` | 循环引擎，只调度 |
| k2cj-explorer | `agents/k2cj-explorer.md` | 发现测试目标 |
| k2cj-translator | `agents/k2cj-translator.md` | 执行 Kotlin→Cangjie 翻译 |
| k2cj-diagnostician | `agents/k2cj-diagnostician.md` | 分类编译错误 |
| k2cj-fixer | `agents/k2cj-fixer.md` | 在 worktree 中修改翻译器 |
| k2cj-verifier | `agents/k2cj-verifier.md` | 全量回归测试 |

## 目录结构

```
.claude/
├── agents/          ← 6 个 agent 角色定义（架构 B）
├── skills/          ← k2cj-optimize 工作流知识（架构 B）
├── guards/          ← 6 个阶段门禁标准（架构 B）
├── pipeline/        ← PLAN.md 流水线状态（架构 B）
└── state/           ← optimization-state.md 持久化记忆（架构 C）
```

## 架构设计

本系统融合三种多 agent 架构：

- **架构 B**（SKILL.md + agent 配置驱动）：skills/ + agents/ + guards/ 的声明式文件系统
- **架构 C**（Loop Engineering）：`/goal` 自动循环 + worktree 隔离 + state 持久化 + 制造/检查分离
- **SOC 理论**：张力=编译错误数，级联=依赖重编译，慢驱动=逐错误 L1 优先修复，收敛=0 errors

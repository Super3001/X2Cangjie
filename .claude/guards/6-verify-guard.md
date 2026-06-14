# Guard: Stage 6 — Verifier 验收

## PASS 条件（全部满足）

- [ ] `cargo build --release` exit 0
- [ ] 全部已有单文件测试通过（187/187）
- [ ] 全部项目测试通过（32/32）
- [ ] SOC 统计稳定（雪崩规模变化 ≤ 5%）
- [ ] 如果本次涉及新语法修复 → 至少新增 1 个针对性测试用例

## FIX 条件

- [ ] 任何已有测试失败 → **REGRESSION**，标记 FIX_NEEDED，回退 worktree
- [ ] SOC 统计显著偏离 → 标记 WARNING，但不阻塞（可能是正确的行为变化）
- [ ] 新增测试失败 → 检查测试用例本身是否正确

## 回归严重度

| 等级 | 条件 | 动作 |
|------|------|------|
| CRITICAL | > 5 个已有测试失败 | 立即回退，标记人工审查 |
| WARNING | 1-5 个已有测试失败 | 回退，分析失败原因，重试 |
| PASS | 0 个失败 | 允许合并到主分支 |

## 检查命令

```bash
cd <worktree>/kotlin2cj
python3 tests/run_tests.py
python3 tests/run_project_tests.py
cargo run -- tests/cases/18_fibonacci.kt --stats
```

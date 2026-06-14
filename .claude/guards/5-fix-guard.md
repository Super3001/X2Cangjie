# Guard: Stage 5 — Fixer 验收

## PASS 条件

- [ ] 修改在独立 worktree 中进行
- [ ] `cargo build` 在 worktree 中成功
- [ ] 修改的文件属于合理范围（不超过 3 个文件）
- [ ] 修改层级 ≤ 诊断建议的层级（L1 优先）
- [ ] state file 已追加本轮修改摘要

## FIX 条件

- [ ] `cargo build` 失败 → 回退 worktree，标记 fix 失败
- [ ] 修改文件数 > 3 → 拆分为多个独立的 L1 fix
- [ ] 同一文件已在另一 worktree 中被修改 → 合并冲突，等待前一个 fix 完成

## 安全约束

- [ ] 不删除任何 `tests/cases/*.kt` 文件
- [ ] 不修改 `tests/cases/*.expected` 文件（除非新增测试）
- [ ] 不修改 `.gitignore`

## 检查命令

```bash
cd <worktree> && cargo build 2>&1
echo "EXIT: $?"
git diff --stat HEAD
```

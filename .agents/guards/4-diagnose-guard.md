# Guard: Stage 4 — Diagnostician 验收

## PASS 条件

- [ ] 所有编译错误被归类到六大类别之一
- [ ] 每个错误有 `root_cause` 描述（指向具体源文件和行号）
- [ ] 每个错误有 `fix_direction`（L1/L2/L3 + 具体方法名）
- [ ] 按 `fix_priority` 排序
- [ ] `unclassified` 数量 = 0（或 ≤ 10% 总错误数）

## FIX 条件

- [ ] 有未归类错误 → 标记 `unclassified`，降低优先级继续
- [ ] 所有错误指向同一个根因 → 合并为单次修复

## 输出验证

检查诊断 JSON 的结构完整性：

```bash
python3 -c "
import json
with open('diagnosis_r<N>.json') as f:
    d = json.load(f)
assert 'total_errors' in d
assert 'classified' in d
assert all('category' in c and 'fix_direction' in c for c in d['classified'])
print('OK')
"
```

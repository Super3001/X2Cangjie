# Guard: Stage 3 — Compiler 验收

## PASS 条件

- [ ] `cjpm build` 在翻译产物目录 exit code = 0
- [ ] 0 个编译错误
- [ ] 0 个编译警告（或警告数未增长）

## FIX 条件（有错误 → 进入诊断）

- [ ] 编译错误数 > 0 → 收集完整 stderr，传递给 Stage 4
- [ ] 编译超时（> 120s）→ 记录，可能是无限循环翻译产物

## 特殊判据

- 如果只有 `unused import` 类 warning → 仍算 PASS（不阻塞）
- 如果错误数比上轮减少 → FIX_PROGRESS（继续迭代）
- 如果错误数与上轮相同且 > 0 → FIX_STUCK（需人工介入）

## 检查命令

```bash
cd output/<target>_cj && cjpm build 2>&1 | tee ../compile_errors_r<N>.log
echo "ERROR_COUNT: $(grep -c 'error' ../compile_errors_r<N>.log)"
```

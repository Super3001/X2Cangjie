# Guard: Stage 2 — Translator 验收

## PASS 条件

- [ ] `kotlin2cj` 二进制存在且可执行
- [ ] 对每个 `.kt` 文件生成了对应的 `.cj` 文件
- [ ] 翻译产物目录结构完整（含 `cjpm.toml`）
- [ ] 翻译过程中无 panic / crash
- [ ] 返回了 SOC 统计（节点数、雪崩规模）

## FIX 条件

- [ ] 翻译失败文件数 > 0 → 记录失败清单，继续后续阶段
- [ ] 翻译崩溃 → 报告错误，标记为 PARSER_GAP

## 检查命令

```bash
ls kotlin2cj/target/release/kotlin2cj && echo "BINARY_OK"
find output/<target>_cj -name "*.cj" | wc -l
test -f output/<target>_cj/cjpm.toml && echo "CJPM_OK"
```

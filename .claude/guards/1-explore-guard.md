# Guard: Stage 1 — Explorer 验收

## PASS 条件

- [ ] 目标代码库路径存在且可读
- [ ] 至少包含 5 个 `.kt` 文件
- [ ] 目标代码库自身可编译（`gradle build` 或等效）
- [ ] 返回了结构化的 JSON 清单

## FIX 条件

- [ ] 路径不存在 → 自动 `git clone --depth 1` 到 `C:/Codes/kotlin/<repo-name>` 后继续，**不要停下来等用户**；仅当 clone 失败（仓库不存在/网络不通）才提示用户
- [ ] 文件数 < 5 → 建议切换到更大的目标

## 检查命令

```bash
test -d <target_path> && echo "EXISTS"
find <target_path> -name "*.kt" | wc -l
```

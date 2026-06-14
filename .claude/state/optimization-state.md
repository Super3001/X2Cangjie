# kotlin2cj 优化状态

> 跨 run 持久化。每轮 fixer 追加，orchestrator 启动时先读。

---

## ksoup R0 完成 (2025-06-14)

### 诊断
997 编译错误 → 单根因：var-func 命名冲突

### 核心修复
`engine.rs` — `resolve_var_func_collisions()`:
- 扫描 Class 节点，var/func 同名时重命名 var 为 `_<name>`
- 级联更新所有 NameRef 引用
- ksoup 实测: 5 对冲突消解 (_padding, _size, _isPacked, _outputSettings, _quirksMode)

### 测试
202/202 单文件翻译通过，0 回归。29/100 ksoup 文件翻译成功。

### 翻译器版本
分支: `ksoup-entities-validation-2-2`
修改: `engine.rs`, `parser.rs`

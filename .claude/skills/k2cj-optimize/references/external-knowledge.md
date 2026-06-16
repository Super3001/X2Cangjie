# 外部知识导入规范

> 统一定义 kotlin2cj 和 x2cj-test 两个项目各自从 x2cj-skills 加载什么知识、以什么顺序加载。
> 本文件放在 SunriseSummer-X2Cangjie 仓库，供两个项目的 agent 共同遵守。

---

## 一、知识源（x2cj-skills 提供）

所有外部知识来自 `~/x2cj-skills/`，按类别四层：

### Kotlin→Cangjie 翻译规则（kotlin2cangjie 分支）

> **来源**：`~/x2cj-skills/` 仓库 `kotlin2cangjie` 分支，`skills/x2cj/rules/docs/kotlin/` 目录（30 个规则文件）。
> 每条规则有 `@kpattern`/`@kmethod`/`@kclass` 标注 + Kotlin→Cangjie 逐行对照示例。
> **这是 kotlin2cj 优化系统的一级知识源**——Kotlin 独有语法糖不在 Java rules 覆盖范围内。

| 类别 | 规则文件 | 覆盖内容 |
|------|---------|---------|
| **类型映射** | `hashmap.md` | `MutableMap`→`HashMap`、`getOrElse`→`get().getOrDefault()` |
| | `set.md` | `MutableSet`/`HashSet`→`HashSet` |
| | `array-arraylist.md` | `MutableList`→`ArrayList`、`Array`、`ByteArray`→`Array<Byte>`、`ArrayDeque`→`ArrayList` |
| | `option.md` | `T?`→`?T`、`null`→`None`、`?:`→`??`、`!!`→`.getOrThrow()`、`?.`、`as?`→`as` |
| **语法糖** | `class-interface.md` | `data class`→Equatable/Hashable/ToString、`sealed class`→`open class`+`static let`、nested class→top-level、`companion object`→`static`、`by lazy`、`lateinit`、`object`单例、primary constructor |
| | `function.md` | `fun`→`func`、`vararg`→`Array<T>`、默认参数 `!` 标记、extension function→`extend` |
| | `generics.md` | `<T : C>`→`where T <: C`、`out`/`in` 方差→删除、`reified`→删除 |
| | `keyword.md` | 标识符与 Cangjie 60+ 关键字冲突→反引号转义、`typealias`→`type` |
| | `top-level.md` | 顶层声明可见性差异 |
| **表达式** | `collection-ops.md` | `map`/`filter`/`forEach`/`fold`→Cangjie pipeline `|>` + `collectXxx` |
| | `lambda.md` | lambda/SAM |
| | `scope-function.md` | `let`/`also`/`apply`/`run`/`with` |
| | `when.md` | `when`→`match` |
| | `control-flow.md` | 控制流 |
| **库映射** | `regex.md` | `Regex`（Cangjie `std.regex` 有对应类型） |
| | `file.md` | 文件 I/O |
| | `logging.md` | 日志 |
| | `okhttp.md` | OkHttp |
| | `retrofit2.md` | Retrofit |
| | `json-serialize.md` | JSON 序列化 |
| **基础** | `basic-syntax.md` | 基础语法对照 |
| | `string.md` | String 操作 |
| | `math.md` | 数学运算 |
| | `random.md` | 随机数 |
| | `range.md` | Range |
| | `sort.md` | 排序 |
| | `thread.md` | 线程 |
| | `ref-eq.md` | `===` 引用相等 |
| | `enum.md` | enum 带状态/无状态 |
| | `exception.md` | try/catch/throw |

### Java→Cangjie 翻译规则（main 分支，已验证）

| 路径 | 内容 | 行数 |
|------|------|:--:|
| `skills/x2cj/rules/docs/java/basic/*.md` | 类型映射、关键字转义、泛型 | — |
| `skills/x2cj/rules/docs/java/class/*.md` | interface/enum/嵌套类/Lombok/Option | — |
| `skills/x2cj/rules/docs/java/concurrent/*.md` | 并发 | — |
| `skills/x2cj/rules/docs/java/operator/*.md` | 运算符 | — |
| `skills/x2cj/rules/docs/java-platform/collection/*.md` | Collection/Map 映射 | — |
| `skills/x2cj/rules/docs/java-platform/io/*.md` | Stream/Reader/Writer/序列化 | — |
| `skills/x2cj/rules/docs/java-platform/*.md` | 其余 java-platform 子目录 | — |
| `skills/x2cj/rules/tpc-dependency-mapping.md` | TPC 依赖映射 | — |
| `skills/x2cj/rules/code-style.md` | 代码风格 | — |

### 仓颉语言参考

| 路径 | 内容 |
|------|------|
| `skills/cangjie-dev/SKILL.md` | 仓颉开发总入口 |
| 其下子文档 | 语法特性、标准库、扩展库、工具链 |

### 评估标准

| 路径 | 内容 |
|------|------|
| `skills/x2cj-eval/skill.md` | LLM 语义评估流程 + prompt 模板（14 子维度） |

---

## 二、各项目加载声明

### kotlin2cj 优化系统

**加载者**：k2cj-diagnostician、k2cj-fixer、k2cj-verifier

**加载顺序**：

```
1. kotlin-cangjie-patterns.md        ← 项目私有：已知模式快查（85行，快速索引）
2. Kotlin→Cangjie 规则（30文件）      ← 一级知识源：Kotlin 独有语法糖 + stdlib 类型映射
   2a. 类型映射: hashmap, set, array-arraylist, option
   2b. 语法糖:   class-interface, function, generics, keyword, top-level
   2c. 表达式:   collection-ops, lambda, scope-function, when, control-flow
   2d. 库映射:   regex, file, logging, okhttp, retrofit2, json-serialize
   2e. 基础:     basic-syntax, string, math, random, range, sort, thread, ref-eq, enum, exception
3. fix-history.md                    ← 项目私有：历次修复记录（避免重复修复）
4. Java→Cangjie 规则                 ← 补充：共享 JVM 生态的 API（Java rules 覆盖 Kotlin rules 未覆盖的 java.*/javax.*）
5. cangjie-dev 语言参考               ← 外部：确认仓颉 API 合法性
6. x2cj-eval                         ← 外部：语义评估标准（G10 判据）
```

> **核心原则**：Kotlin rules（第 2 层）是 kotlin2cj 的一级知识源。Kotlin 独有的语法糖（extension function、companion object、data class、`?.let` 等）不在 Java rules 覆盖范围内。Java rules（第 4 层）只作为补充——覆盖 Kotlin rules 未涉及的 `java.*`/`javax.*` 等 JVM 标准库类型。
>
> **Diagnostician 用法示例**：
> ```
> 编译错误: "error: undeclared type 'MutableMap'"
>   → 查 hashmap.md → "MutableMap→HashMap"
>   → 归类: RENDER_GAP (stdlib 类型映射缺失，需在 render.rs 添加)
> ```
>
> **Fixer 用法示例**：
> ```
> 任务: 修复 "error: undeclared type 'MutableMap'"
>   → 查 hashmap.md → Cangjie 写法: HashMap<K, V>
>   → 在 render.rs 的类型映射表中添加: kotlin.collections.MutableMap → std.collection.HashMap
> ```

### x2cj-test 验证系统

**加载者**：x2cj-test orchestrator、review-agent、gate-agent

**加载顺序**：

```
1. x2cj rules (syntax > io > ...) ← 外部：Java→Cangjie 规则（验证翻译是否遵循已知规则）
2. cangjie-dev 语言参考            ← 外部：确认仓颉侧的 API/语法是否正确
3. x2cj-eval                      ← 外部：语义评估标准（Stage 2 入口门禁）
```

> x2cj-test 不需要项目私有知识——它是通用验证系统，不绑定特定源语言的项目模式。

---

## 三、加载规则

### 时机

- **diagnostician / fixer**：每次被调用时加载（任务之间上下文不共享）
- **verifier / reviewer**：语义评估阶段加载
- **gate-agent**：执行 guard 检查前按需加载（如 Stage 2 guard 需要 x2cj-eval 的评分标准）

### 顺序原则

```
便宜先查 → 贵后问
   │           │
   │      ┌────┴────┐
   │      │         │
本地文件  已有规则   LLM自由裁量
（0 token）（已有答案）（需要推理）
```

1. 先查本地私有知识（已有答案，不走 LLM）
2. 再查 Kotlin→Cangjie 规则（Kotlin 特有，已验证映射）
3. 再查 Java→Cangjie 规则（JVM 共享 API，补充覆盖）
4. 再查语言参考（确认语法/API 合法性）
5. 最后查评估标准（判断"对不对"的依据）
6. 以上都不确定时，才让 LLM 自行判断

### 不做的事

- ❌ agent 不跨项目加载对方的私有知识
- ❌ 不把规则文档全文塞进 prompt（只查相关条目）
- ❌ 不在对话 context 里记知识查询结果（查完就用，不缓存到 context）

---

## 四、kotlin2cangjie 分支同步

```
x2cj-skills 仓库结构:
  main 分支      → Java→Cangjie 规则（skills/x2cj/rules/docs/java*/）
  kotlin2cangjie 分支 → Kotlin→Cangjie 规则（skills/x2cj/rules/docs/kotlin/）

同步命令:
  cd ~/x2cj-skills && git fetch origin kotlin2cangjie
  git worktree add /tmp/x2cj-skills-kotlin2cangjie origin/kotlin2cangjie
```

Agent 通过 git worktree 或直接读取 `~/.hermes/skills/x2cj/` 下的 symlink 获取 Kotlin 规则。

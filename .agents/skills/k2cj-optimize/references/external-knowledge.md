# 外部知识导入规范

> 统一定义 kotlin2cj 和 x2cj-test 两个项目各自从 x2cj-skills 加载什么知识、以什么顺序加载。
> 本文件放在 SunriseSummer-X2Cangjie 仓库，供两个项目的 agent 共同遵守。

---

## 〇、x2cj-skills 仓库路径（按启动环境）

| 启动环境 | x2cj-skills 路径 |
|---------|-----------------|
| Windows 上启动 Claude Code | `C:/Codes/x2cj-skills` |
| WSL 上启动 Claude Code | `/mnt/c/Codes/x2cj-skills` |

> 两者是同一份磁盘内容。历史文档中的 `~/x2cj-skills/` 写法已废弃（该路径在两个环境下均不存在），下文以 `<x2cj-skills>` 指代按环境解析后的实际路径。

> **知识库权威清单见 `knowledge-registry.md`（注册表）**：本文件定义流程（加载顺序、查证门），
> 注册表定义数据（有哪些库、入口索引、查证链位次）。新增知识库只改注册表，本文件流程不动。

## 一、知识源（x2cj-skills + 本仓库 .github/skills 提供；注册表 kb-self / kb-x2cj 的展开说明）

外部知识按类别四层：

### Kotlin→Cangjie 翻译规则（main 分支）

> **来源**：`<x2cj-skills>/skills/x2cj/rules/docs/kotlin/` 目录（31 个规则文件，已从 kotlin2cangjie 分支合入 main）。
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
| | `coroutines.md` | 协程 |
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
| `skills/x2cj/rules/tpc-dependency-mapping.md` | **TPC 三方库映射**（~140 行 GitCode Cangjie-TPC 表，附 cjpm.toml 依赖片段）——查证门位次 ④ | — |
| `skills/x2cj/rules/sdk-dependency-mapping.md` | **二方库映射**（Java 库已 1:1 移植仓颉，无外部 git 依赖）——查证门位次 ③ | — |
| `skills/x2cj/rules/code-style.md` | 代码风格 | — |

### 仓颉语言参考

**一级来源：本仓库 `X2Cangjie/.github/skills/`（agent 配置实际引用的路径，无需跨仓库）**

| 路径 | 内容 | 引用者 |
|------|------|--------|
| `.github/skills/cangjie-std/` | 仓颉标准库（core/collection/convert/crypto 等） | diagnostician, fixer, semantic-guard |
| `.github/skills/cangjie-lang-features/` | 仓颉语法特性（判断是否语言层面不可翻译） | diagnostician, semantic-guard |
| `.github/skills/cangjie-stdx/` | 扩展库（http/json/encoding 等） | 按需 |
| `.github/skills/cangjie-toolchains/` | 工具链（cjc/cjpm/cjlint 等） | 按需 |
| `.github/skills/cangjie-original-docs/` | 仓颉官方原始文档 | 按需 |
| `.github/skills/cangjie-regulations/` | 仓颉编码规范 | 按需 |

**补充来源：`<x2cj-skills>/skills/cangjie-dev/`**（仓颉开发总入口 SKILL.md + docs 子文档，内容与上表有重叠，本地 `.github/skills/` 查不到时再查）

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
2. Kotlin→Cangjie 规则（31文件）      ← 一级知识源：Kotlin 独有语法糖 + stdlib 类型映射
   2a. 类型映射: hashmap, set, array-arraylist, option
   2b. 语法糖:   class-interface, function, generics, keyword, top-level
   2c. 表达式:   collection-ops, lambda, scope-function, when, control-flow
   2d. 库映射:   regex, file, logging, okhttp, retrofit2, json-serialize
   2e. 基础:     basic-syntax, string, math, random, range, sort, thread, coroutines, ref-eq, enum, exception
3. fix-history.md                    ← 项目私有：历次修复记录（避免重复修复）
4. Java→Cangjie 规则                 ← 补充：共享 JVM 生态的 API（Java rules 覆盖 Kotlin rules 未覆盖的 java.*/javax.*）
5. 仓颉语言参考                       ← 一级: .github/skills/cangjie-std + cangjie-lang-features；补充: <x2cj-skills> cangjie-dev
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

### 3.5 查证门：写 stub / 手写库实现之前必查（API-first）

**任何"注入 stub / 手写实现某库功能"的修复决策之前，必须按注册表查证链走一遍索引级查询，
并留查证记录。** 查证链位次的权威定义在 `knowledge-registry.md`，当前为：

```
① cangjie-std/SKILL.md（std 25 包索引，grep 类型/功能名）
② cangjie-stdx/SKILL.md（扩展库 11 包索引）
③ <x2cj-skills>/skills/x2cj/rules/sdk-dependency-mapping.md（二方库表）
④ <x2cj-skills>/skills/x2cj/rules/tpc-dependency-mapping.md（TPC 三方库表）
⑤ 兜底（仅前四步无命中且怀疑索引不全时）：cangjie-original-docs/index/stdlib.md
   或 <x2cj-skills>/skills/cangjie-dev/SKILL.md
```

- **为什么**：stub 是永久负债（终身跟随仓颉 stdlib 演进 + 语义漂移风险），映射到真实 API 的
  维护费≈0（官方替你演进）。查证花 ≤5 次索引读取，省下的是终身跟随费——这是知止之秤的直接
  推论。fix-history 2026-07-06 已有事后原则"真实包映射优先（Regex→std.regex），无对应物注入
  最小 stub"，本门把它前移为决策时规则。
- **预算纪律**：查证是**索引级**的——grep 入口索引文件，命中再读至多 1 个详情页，
  **总计 ≤5 次文件读取**。严禁遍历 485 文件的官方镜像目录。
- **查证记录落两处**：
  - 诊断时：diagnostician 的簇 JSON 填 `api_check` 字段（见 k2cj-diagnostician.md，
    STDLIB_GAP / undeclared 类簇必填）
  - 修复后：fix-history.md 修复条目加一行 `- **查证**: 查①②③④，verdict …`
    （随修复记录归档，state 只留战役级候选）

### 不做的事

- ❌ agent 不跨项目加载对方的私有知识
- ❌ 不把规则文档全文塞进 prompt（只查相关条目）
- ❌ 不在对话 context 里记知识查询结果（查完就用，不缓存到 context）

---

## 四、x2cj-skills 仓库同步

Kotlin 规则已从 `kotlin2cangjie` 分支合入 `main`，main 分支同时包含 Java 与 Kotlin 规则，**不再需要单独 fetch 分支或建 worktree**：

```
x2cj-skills 仓库结构（main 分支）:
  skills/x2cj/rules/docs/java*/   → Java→Cangjie 规则
  skills/x2cj/rules/docs/kotlin/  → Kotlin→Cangjie 规则（31 文件）
  skills/cangjie-dev/             → 仓颉开发参考
  skills/x2cj-eval/               → 语义评估标准

同步命令（Windows / WSL 任一环境执行即可，同一份磁盘内容）:
  git -C C:/Codes/x2cj-skills pull          # Windows
  git -C /mnt/c/Codes/x2cj-skills pull      # WSL
```

> 历史做法（已废弃）：早期 Kotlin 规则只在 `kotlin2cangjie` 分支，需 `git worktree add /tmp/x2cj-skills-kotlin2cangjie origin/kotlin2cangjie` 或读 `~/.hermes/skills/x2cj/` symlink。合入 main 后直接读主 checkout 即可。

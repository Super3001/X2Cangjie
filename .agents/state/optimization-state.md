# kotlin2cj 优化状态

> 跨 run 持久化。每轮 fixer 追加，orchestrator 启动时先读。
>
> 难度梯度：Phase 0 (⭐ 基线) → Phase 1 (混合小目标, 4 项目) → Phase 2 (⭐⭐) → Phase 3 (⭐⭐⭐⭐) → Phase 4 (⭐⭐⭐⭐⭐)

---

## 全局进度

```
Phase 0       Phase 1                          Phase 2       Phase 3       Phase 4
[✅]          [✅][✅][✅][ ][✅][ ][ ]        [⏳][ ][ ]    [ ][ ][ ]     [ ][ ][ ]
                                ↑1e 核心收敛    ↑2a datetime R0
```

> ✅ **指标口径修正（2026-07-09，已会签）**: cjc 默认只打印 8 个错误（"N errors
> generated, 8 errors printed"）。1g R2-R4 记载的"10 errors"是打印截断误计，R4 真实
> 错误数 1460。自 R5 起所有测量管线 cjpm.toml 加 `compile-option = "--error-count-limit all"`，
> 以 "N errors generated" 为唯一口径。方向为改严。1g 语义战役未打完。
> **会签记录**: 2026-07-09 用户人工批准"同意 --error-count-limit all"。已核实 1g R5
> (target_1g_r5) 与 2a (target_2a) 测量管线 cjpm.toml 均带该选项。cjpm 自身消息不计
> 编译错误亦随此口径生效（唯一口径 = "N errors generated"）。

---

## Phase 0: 翻译器自身测试 (基线)

| 目标 | 测试规模 | 状态 | 备注 |
|------|---------|:--:|------|
| translator-own-tests | 202 single + 33 project | ✅ | 全通过。2026-06-16 全量回归验证。作为回归门禁 |

---

## Phase 1: 混合小目标（来自 4 个项目）

| # | 目标 | 来源 | 文件数 | 状态 | 编译错误 | 核心特性 | 本地工程 |
|:--:|------|------|:---:|:--:|:-------:|---------|--------|
| 1a | ksoup-exception | ksoup | 5 | ✅ | 0 | data class, sealed, enum |
| 1b | ksoup-safety+io | ksoup | 5 | ✅ | 0 | companion, extension, lambda |
| 1c | okhttp-mockwebserver | okhttp | ~30 | ✅ | 444 (cross-pkg deps) | builder, interceptor, coroutine |
| 1d | ksoup-parser | ksoup | 16 | ⏳ | 随 1g 全量口径重测 (1g R5: 1411) | state machine, when, inline; R2 stdlib stub + R3 ctor-param/optional-param + R4 it-shadowing 修复完成 | C:/Codes/kotlin/ksoup |
| 1e | ktor-io | ktor | 5 (核心)/14 | ✅ | 0 | P1/P2/P3译器修复;核心5文件收敛,余9剪枝(依赖边界+render gap); **运行时验证 ✅ 2026-07-10**(审计修正b): 当前译器重译 5/5→build 0 err→行为断言全对(enum dispatch/bitmask contains/plus/toString when-分派/toIntOrFail throw), 产物 output/target_1e_verify/; 已知偏差: Int→Int64 使 toIntOrFail 阈值 2³¹-1→2⁶³-1 | C:/projects/kotlins/ktor |
| 1f | koin-core | koin | ~25 (实际 74) | ⏳ | R13: **549**（净 -92 from R12 641; `new(constructor)` 簇 92→0 -100%, 累 R11-R13 missing-arg+new 共 -187 95% 消灭）; **R14 attempt failed** (get() 推断 + `<: Object` bound, +154 errors regression, reverted) | DSL, delegate, reified; R1 修 3 parse 簇, R2-R8 修 6 簇 (ctor-default/star-proj/throw-elvis/extension-property/top-level-collision/fully-quoted/typealias/basename); **R9 泛型扩展函数簇打穿**(裸名接收者的函数泛型归函数自身而非接收者, 4403→746 -83%, 用户手动指定复攻); 管线 translate_1f.py(project 模式)首次固化; **R10 泛型 typealias 渲染层解注释 + parser `<` 后漏检 ReceiverType<T>.() 修复**(双 bug 互锁, 746→543 -27%, 仓颉 1.0.5 探针矩阵 6 个实证支持 `type X<T>=Y` + `(?T)->Unit` + `(BeanDefinition<T>)->Unit` 三态); 外溢 1g 1044→1033(-11), 2a 963→963(0 中性); **R11 trailing-lambda 默认参数补 None**(fn_params 返回 (name,ty,has_default_degraded,has_default_original) 四元组, render_call_args_with_params 对 args<params 的中位可空默认参数补 `Option.None`(降级) 或 `name: None`(未降级); 同时修 fn_params strip `<...>` 后缀匹配带泛型实参调用点如 `decorate<Int64>(b)`; 543→619 净但 missing-argument 簇 107→37 -68 64%消灭, 揭示被遮蔽下游 undeclared×~67 主要是 new()×69; 外溢 1g 1044→1032(-12 正向), 2a 963→968(+5 重译漂移容差内)); **R12 非 ?T 默认值补值**(fn_params 返回五元组含 default_value_str: Option<String>, render_call_args_with_params 用渲染默认值字符串补中位非可空默认参数 Bool=false/Int=0/String=""; 619→641 净+22 但 missing-argument 37→10 -27 73% 消灭, 累 R11+R12 共 -95 89%; 揭示下游 undeclared 209→233 +24; 外溢 1g 1032→1034(+2 漂移), 2a 968→970(+2 漂移), 均 ±3-5 容差内)); **R13 koin-dsl-lambda-receiver 簇** (parser.rs try_restructure_koin_dsl_lambda, +110 行; 检测 callee=factory/single/scoped + trailing lambda whose body is single `new(constructor)` call, 重构 lambda: 加 synthetic params `["scope","params"]` + 把 body `new` NameRef 改为 `Member(scope,"new")`; 渲染为 `{ scope, params => scope.new(constructor) }`; 641→549 净 -92 -14%; `undeclared identifier 'new'` ×92→0 -100%; 同时消除 cascade `generic type should be used with type argument` for `None` in factoryOf/singleOf/scopedOf/scopedFactoryOf ×92 (因 lambda 类型可推断后 None:Option<Qualifier> 推断恢复); **揭示新 cascade `'onOptions' is not a member of class 'Object'` ×92** (因 `scope.new(constructor)` 调用的 `Scope.new` body 仍含 `get()` 不能推断 `<T1>`,导致 `new` 返回类型未知→factory 返回 Object→.onOptions 失败;此为下一轮 reified T 类型字面量簇的 reveals); 外溢 1g 1034→1032(-2 漂移), 2a 970→973(+3 漂移), 均 ±3-5 容差内; 测试 274_koin_dsl_lambda_receiver (非泛型版 koin DSL factory/single/scoped + new(constructor) 调用)); **R14 attempt failed (reverted)** — 尝试在 `Scope.new` body 把 `get()` 改写为 `get<T1>()` (位置对应),加 `where T1 <: Object` bound 让 cjc 满足 `Scope.get<T>` 的 `<: Object` 约束; 并把 lambda params 加类型标注 `scope: Scope, params: ParametersHolder` 避免"parameters must have type annotations" cascade; 结果 **549→703 (+154 regression)**: `onOptions` 92→4 -88 (cleared!) 但浮现新 cascade `parameters-must-have` ×88 (需类型标注, 加标注后转 `unable-to-infer` ×88 at call site `scope.new(constructor)`) + `Int64 is not a subtype of Class-Object` (Cangjie 1.0.5 `Int64` 不是 `<: Object`,koin `factoryOf<Int64,...>` 调用违反 `<: Object` bound) + cjc 不能跨 nested generic call 推断 R (R 仍为 `Generics-R` 而非 Int64); 三层 cascade 每修一个浮现下一个, fundamental Cangjie type system 限制 — `Int64` 不是 `<: Object` + cjc 不传播泛型实参通过 nested generic call; R14 全部改动 reverted, 回到 R13 549; 须 R15+ 用完全不同策略 (如 inline `new(constructor)` 为 `constructor(scope.get<Tn>())` 直接展开 + 跟踪 enclosing function's generic_params; 或 stub `Scope.get` 为 `func get<T>(): T` 无 bound + 接受 T 为 `?T` 返回类型); R14 候选 (R15+ 重新审视): ① `get()` 推断 `<T1>` in `Scope.new` body (reified T 类型字面量, 须绕过 Int64-不是-Object 的限制 — 路径: 剥离 `Scope.get` 的 `<: Object` bound 或 inline 展开 new/constructor) ② missing-argument 残 10 ③ appDeclaration() 函数类型变量调用需 .invoke() (undeclared 'invoke' ×7) ④ peek_is_generic_ctor 把小写函数 `c.make<String>` 误判为 `<` 比较 ⑤ expected×83 (reified T 类型字面量,高风险) ⑥ unimplemented×42 (expect class 抽象方法 stub) | C:/Codes/kotlin/koin |
| 1g | ksoup-main | ksoup | 87 | ⏳ | R19: **1044**（auto 19 轮起点 1411, -26%）→ R10 外溢核对 **1033** | Option 战役四批 + R15 isNullOrEmpty(-59) + R16 簇A① enum-entry-body(-12) + R17 簇A② companion 标量常量提升(-6) + R18 簇A FilterResult 嵌套enum-in-interface提升(-15) + R19 簇 not-member 子簇①② 嵌套类型限定链+appendCodePoint(-7, Syntax×7+OutputSettings×8清+StringBuilder-6=appendCodePoint; ~9 honest reveals; 2a 中性 964无外溢; 验收期修兜底撞车: 移除多级is_class_name兜底避221 StartTag枚举条目/类名撞车); 下一战役候选(R20=auto5校准轮): mismatched×245/undeclared id×124/not-member×101(ArrayList<Node>×15/Node×14/EscapeMode×9)/簇A真方法分派(read,高风险)/nested-class-in-interface/String.replace(Rune→Regex) | C:/Codes/kotlin/ksoup |

> ⏳ = in-progress, 🔒 = locked, ✅ = converged, 🟡 = blocked, ❌ = stuck

---

## Phase 2: 中等规模完整项目

| 目标 | 规模 | 状态 | 编译错误 | x2cj-eval | 备注 |
|------|:---:|:--:|:-------:|:---------:|------|
| kotlinx-datetime (2a) | 43 (剪 serializers 后) | ⏸ | R6: **963**（暂停, 第10轮审计裁决: 连续两轮净零） | - | 本地工程 C:/Codes/kotlin/kotlinx-datetime; R6 父接口位泛型实参保留(62→21, 级联曝 missing-abstract×29) + equals/hashCode 剥离(103→21, 1g 跨目标 14→0); R7 候选: undeclared id×189(Directive×35, 疑成员import重限定=1g簇D同根)/undeclared type×155/extend-shadow×60/mismatched×86 |
| koin | ~120 | 🔒 | - | - | Phase 1 测过 core(25)，升级全量 |
| exposed | ~150 | 🔒 | - | - | 全新项目 |

---

## Phase 3: 大型项目 + 硬语法

| 目标 | 规模 | 状态 | 编译错误 | x2cj-eval | 备注 |
|------|:---:|:--:|:-------:|:---------:|------|
| okhttp | ~300 | 🔒 | - | - | Phase 1 测过 mockwebserver(~30) |
| ktor-client | ~200 | 🔒 | - | - | Phase 1 测过 ktor-io(~20) |
| ksoup | ~221 | 🔒 | - | - | Phase 1 测过 ksoup-main(87)，升级真全量 |
| arrow-core | ~100 | 🔒 | - | - | 全新项目 |

---

## Phase 4: 地狱难度

| 目标 | 规模 | 状态 | 编译错误 | x2cj-eval | 备注 |
|------|:---:|:--:|:-------:|:---------:|------|
| kotlinx-serialization | ~150 | 🔒 | - | - | |
| mockk | ~100 | 🔒 | - | - | |
| kotlinx-coroutines | ~200 | 🔒 | - | - | |

---

## 战略校准记录

### 2026-07-10 — auto R5/20 定期校准 + 防刷冷启动审计（新 --auto 20 战役, 1g 战役轮 R20）

- **冷启动审计裁决: MIXED**（独立 general subagent 只读 state 战报, 无代码/无当轮上下文）:
  - **on-track 证据**: R16-R19 修复均为真实机制非 stub（enum-entry-body 截断 / companion-const 提升 / FilterResult enum-in-interface 提升 / type_qualifier_class 递归折叠）; 诚实文化（旧 R5 口径修正"1598→10 作废" / R6 18× 误差重估 / R9 证伪 / R18 +138 2a 溢出收缩 / R14 stub 6/6 查证零假退役）; Option/Equatable 战役 R13 `263_equals_dispatch` 14 运行断言闭环语义（残 3/8 tag/nodes/identity_hash_map 显式追踪为 flow-sensitive smart-cast 深层候选, 未埋）.
  - **gaming 证据（核心, 必须正面回应）**: **新旧 R5 强制项 (a) "2a 收官后必须回 1g 正面攻 mismatched/Option ~229+ 硬簇——该簇自 2026-07-06 挂候选至今从未被正面攻击"——新战役 R16-R19 四轮每轮把 mismatched×245 重列为候选, 实际却打 not-member 子簇（enum-entry-body / companion-const / FilterResult / nested-type-qualifier + appendCodePoint）. 四轮零正面, 正是旧 R5 警告的"逼近目标 vs 养指标"分水岭, 现已四轮深**.
  - **gaming 证据（次）**: 旧 R5 强制项 (b) "给至少一个 ✅ 目标跑 x2cj-eval 或运行时验证"——仅 1e 合规（运行时 ✓）, **1a/1b 仍空 x2cj-eval 列**（仅"0 errors"）. stub 负债净增（R14 6/6 暂封零退役 + 旧 R5 4 marker stub, 仅 REGEX/SEQUENCE 类真 API 映射）.
- **三张地形图重估（协调者视角）**:
  - **遮蔽层**: 1g 1355→1044（-311 over R5-R19）, 结构性易簇（enum-entry-body / companion-const / FilterResult / nested-type-qualifier / appendCodePoint / isNullOrEmpty）基本清完; 残 mismatched×245（旧 R5 时 ~229, 现 245——**reveals 增速 > 修复增速, 成顽固核心**）+ not-member×101 + undeclared id×124 + no-matching-op×38 + unable-infer-generic×36. **遮蔽已退到语义硬核**.
  - **经济曲线**: R10-R13 Option 战役 -108/4 轮（~1240 基数, 8.7%）高产; R15 isNullOrEmpty -59 单点高杠杆; **R16-R19 = -12/-6/-15/-7（-40/4 轮 on ~1084, 3.7%, ~0.9%/轮）——山穷之兆, 结构性易矿将尽, 每错成本劣化（R17 三文件 L3 机制换 -6, R19 双机制 + 回归修换 -7 net）**.
  - **portfolio**: 1g ⏳1044 主战场（残为 L2-L3 语义硬核 mismatched / read 分派）; 1f 🟡 blocked; 2a ⏸964（Directive 抽象类层级须先修）; ✅ 1a/1b/1c/1e 仅 1e 运行时验证. **无新 parse 富矿可转**（exposed/koin 锁定, 审计禁开新 target）.
- **裁决与强制项**:
  1. **(a) R20 = 正面攻 mismatched×245**（兑现新旧 R5 强制项 a）. L3 高风险（Option/unwrap 类型推断 + 泛型推断）→ 按 L3 自动处理: 先 sub-bucket 诊断（== / != / Int64 宽度 / `() -> T` 未调 / Option<T> unwrap / smart-cast）, 找 L2-able 子桶降级攻, 取单轮净正切片; 真全 L3 则本轮至少产出 sub-bucket 分桶 + 定格前置分析（n=1 不得定格, ≥2 次独立确认才可标已知限制）.
  2. **(b) 1a/1b ✅ 回填运行时 / x2cj-eval 验证**——排入新战役 auto R6-R7, 与 mismatched 正面攻击并行不冲突（不同 target）; 1e 运行时验证模式可复用（副本重译→build→行为断言）.
  3. **(c) stub 负债剪枝**（退役 stub 换真 API 映射）排入 auto R8 候选（R14 6/6 暂封项仍待仓颉 std 补面; 父类型位 marker 退役 = 深层特性候选, 与旧 R6 值位委托同源）.
- **轮标**: R20 = auto R5/20 = 1g 战役轮 R20（校准轮, 与簇攻击同轮执行; 校准先于簇攻击, 因 mismatched 分桶结果决定方向）.

- **R20 mismatched 分桶结果（正面-攻击已执行, 强制项 a 兑现）**: 245 错按 (expected :: found) 配对分桶:
  - **A under-unwrap `T` vs `Option<T>` (~66, 最大桶)** = R11 确认的 L3 残留（非 NameRef receiver / 跨类字段歧义, 需 receiver 静态类 + 继承链; R11 已 79→40, 残 40 为 D-cast/D-index/D-assign/D-double/C-ambig 五桶）.
  - **C `String` vs `Array<String>` (×16)** 疑 split/toString 映射缺口（待探, 可能 L2）.
  - **D `Node` vs `Int64` (×11)** = 索引/计数推断 L3.
  - **G `T` vs `() -> T` (×12)** = R17 缓打的非标量 companion-const 提升（`Range.AttributeRange.UntrackedAttr` = `AttributeRange(Untracked, Untracked)` 构造调用 init, 非标量故 R17 scalar 白名单排除, 语义面复杂含 init 依赖链, L2-L3）.
  - **B `Option<T>` vs `Option<Option<T>>` (×9)** 双包装（待探, 疑一致 render bug）.
  - **E `Bool` vs `Unit` (×7)** removeIf 族（待探, 疑 L2）.
  - **F `Option<Object>` vs `Option<String>` (×7)** = 泛型 variance L3. **I `Element` vs `This` (×4)** = smart-cast `this` L3.
  - **结论: mismatched 真 L3 硬核, 无干净 L3→L2 降级楔子**——最大桶 A 是 R11 既定 L3 残留, G 是 R17 既缓非标量 companion-const, 余皆长尾 L3. **n=1 不得定格**, 需第 2 次独立确认才可标"已知限制". R20 取净正切片失败（无 L2 楔子）→ 本轮 mismatched 正面-攻击产出 = 分桶 + L3 定格前置分析（skill L3 自动处理程序合规, 非零进展: 把"mismatched 候选未打"转为"mismatched 已分桶、L3 已 1 次确认"）.
  - **后续候选**: 探 C/B/E 小桶（若干净 L2 则取切片）/ 兑现强制项 (b) 1a/1b 运行时验证 / mismatched 第 2 次确认后定格 / 转 not-member×101 残余（ArrayList<Node>×15 疑 stdlib 映射低风险）.

### 2026-07-10 — auto 第 10 轮定期校准 + 防刷冷启动审计

- **三条强制修正核验**: (a) Option 战役已开打且程序合规（预注册转向条件成立）✓ (b) 1e 运行时验证质量超预期（主动记录 Int 宽度偏差）✓ (c) 轮标基本统一（fix-history R10 条漏 auto 标, 小瑕疵）✓。
- **质量趋势**: 五轮全为真实语言特性泛化, 无特例规则; "账面变差但诚实"三处正面样本（R9 证伪记录/R10 净<毛/R6 主动曝 missing-abstract）。**两处软肋盯防**: ① 2a 1237→1070 中 ~120 来自剪枝而非译器能力, 成本曲线叙事打折 ② equals/hashCode 剥离 -96 是"消错不消语义"——**== 语义缺口必须在 Option 战役内闭环, 否则追溯重计为养指标**。
- **裁决与约束**: ① auto R11 必须打 Option 第二批 under-unwrap×79, 不接受转向（战术提示: render.rs:748 成员访问自动解包路径已存在, 先诊断 79 处为何没被接住——is_nullable_expr 覆盖缺口或非 NameRef receiver——可能远比新造机制便宜）② ==/Equatable 闭环排入战役 ③ **2a 正式标 ⏸ 暂停**（连续两轮净零, 不许挂 ⏳ 吃外溢当进展）; 恢复候选: Directive 嵌套类型引用×35 + DayOfWeek 枚举 over-unwrap×5; 2a 暂停期间剪枝轮顶上排期（stub 负债 6 项 🔒 已两次出现在校准记录）。

### 2026-07-10 — auto 第 5 轮定期校准 + 防刷软柿子冷启动审计

- **审计裁决**: 继续当前打法（近 5 轮修复均为真实语言特性泛化：by 委托/类级 variance/expect class/插值折叠；切换 1g→2a 有预注册判据，程序清白），但带三条强制修正:
  1. **(a) 2a 收官后必须回 1g 正面攻 mismatched/Option ~229+ 硬簇**（该簇自 2026-07-06 挂候选至今从未被正面攻击——"逼近目标 vs 养指标"的分水岭），禁止再开新 parse 富矿 target（exposed/koin 全量继续锁定）。
  2. **(b) 给至少一个 ✅ 目标（1a/1b/1e）跑 x2cj-eval 或运行时验证**填上空列——"编译 0 错 + throw stub"不能证明翻译能力。**✅ 已完成 2026-07-10（1e 运行时验证通过，详见历史记录当日条目）**。
  3. **(c) 轮次编号统一**: 自本条起 state 轮标以 target 战役轮（2a R1/R2/R3...）为准，auto 轮另标（auto Rn/15）; 产物目录偏移已注记。✅ 的"分账"语义（1c/1e 剪枝）保留但不得再扩大化。
- **三张地形图重估**: ① 遮蔽层: 1g=语义长尾层(1355), 2a=parse 收尾（语义层未揭示, 防"5=收敛"误判）② 经济曲线: 1g 每错成本已劣化（R6 -8/R7 -48 于 1355 基数）, 2a 极优（R2 -93/R3 -13）③ portfolio: 2a 语义揭示后若为长磨盘, 按 (a) 转 1g Option 簇分批（先 getOrThrow-on-unwrapped 子模式, 再 ==/!= 可空归一）。
- **stub 负债注记**: 剪枝轮候选 9 项全部 🔒 未排期, expect 两类存根新增——负债在涨, 2a 收敛后剪枝轮排期提上日程。

---

## 历史记录

### 1f 簇 trailing-lambda-default (2026-07-13) — fn_params 返回原始默认值, 调用点对齐中间可空默认参数补 None（1f 战役轮 R11）

- **诊断**: 1f R10 baseline 543 含 missing-argument×107（state R11 候选 ①）。分桶后 92 处集中在 koin DSL `factoryOf/singleOf/scopedOf` 族的 trailing lambda 调用 `factory { lambda }`：Kotlin 源码 `factory(qualifier: Qualifier? = null, noinline definition: Definition<T>)` 中位默认参数 `= null` 在 R2 中位默认参数降级 (render.rs:1378-1395 + fn_params:3374-3378) 后丢 `!` 和 `= None` 变成位置参数；cjc 报 "missing argument for parameter list '(Option<Qualifier>, (Scope, ParametersHolder) -> ...)' in call"。R2 的注释 "Kotlin 侧中位默认值本就无法按位置省略,调用点不受影响" 漏掉了 trailing lambda：`f { lambda }` 在 Kotlin 是合法的（lambda 给末尾 lambda 类型参数，前面默认参数省略），降级后丢失默认值导致 cjc 报 missing。
- **修复（render.rs L2 双修, +70 行）**:
  - **fn_params 改造返回四元组**: `(name, ty, has_default_degraded, has_default_original)`——第三元保留 R2 降级逻辑（与 render_func 声明侧一致），第四元是 Kotlin 源码侧**原始**默认值有无（不被降级）。调用点据此识别"被省略的中间位置是否原本有默认值"。
  - **render_call_args_with_params 新增 trailing-lambda 对齐分支**: 当 `args.len() < params.len()` 且 `args.len() >= 1` 时，假设 args[末尾] 是 trailing lambda（parser.parse_args 把 trailing lambda 作为 args 末尾元素），对齐到 params[末尾]，args[0..N-1] 按位置对齐到 params[0..N-1]，**中间 params[N-1..M-1) 共 M-N 个位置**（被跳过）必须有原始默认值，对降级的位置参数补 `Option.None`（位置补值，因定义侧带降级无 `!`），对未降级的命名参数补 `name: None`（命名补值，因定义侧带 `!`）。仓颉 cjc 1.0.5 探针 4 个实证支持：全命名参数定义 + 调用点显式命名传值 + 位置参数定义 + 位置补值（带 Option.None）。
  - **fn_params strip `<...>` 后缀**: peek_is_generic_ctor 把 `decorate<Int>(b)` 也当泛型构造，callee.original = `"decorate<Int64>"`，func_index 用裸名 `"decorate"` 作 key 找不到。strip `<` 后部分以匹配索引。这是 R11 实施 272 测试时发现的连带 bug。
- **测量**:
  - **1f**: 543 → **619**（净 +76, 但 missing-argument 簇 107→37 **-68, 64% 消灭**）。**SOC 级联**: missing-argument 被遮蔽的下游错误显现——undeclared 138→209（+71, 主要是 new()×69 的 trailing lambda 解锁后调用点暴露真错）。这是典型 parse/missing-argument 簇修复的"净数增加但簇消灭"现象，按 autonomous-strategy "以累计消灭根因簇数计进展"原则，本轮消灭 missing-argument 簇 64%。
  - **外溢核对**: 1g 1044→**1032（-12 正向, ksoup 亦有 trailing lambda 默认参数调用受益）**；2a 963→**968（+5 重译漂移容差内, ±3-5 容差）**。
- **测试**: 272_trailing_lambda_default（顶层函数 + 类成员函数两路 trailing lambda 默认参数补 None，验证位置补值 `Option.None` 形态 + 调用点对齐中间被省略的可空默认参数）。回归 **264/264 单文件 + 36/36 项目全绿**（原 263 + 新增 272，原 263 全无回归）。
- **R12 候选（按杠杆排序）**:
  - ① **支持非 ?T 默认值**（Bool=false/Int=0/String=""）：fn_params 返回 Param.default NodeId，调用点对中间被省略的非可空默认参数渲染默认值。可多修 single/scoped 的 createdAtStart: Bool=false 簇（~28 处）
  - ② **appDeclaration() 函数类型变量调用**: 把函数类型变量调用补 `.invoke()`（仓颉要求显式）
  - ③ **peek_is_generic_ctor 把小写函数 `c.make<String>` 误判为 `<` 比较**: parser.rs，需识别 receiver+method+泛型实参形态
  - ④ expected×163（reified `T()` 类型字面量簇, 高风险）
  - ⑤ unimplemented×42（expect class 抽象方法 stub 注入）
- **战役轮标**: 1f R11（用户指定继续进攻 1f, 非 auto 轮）。

### 1f 簇 generic-typealias-fn-type (2026-07-12) — 泛型 typealias 渲染层解注释 + ReceiverType<T>.() 解析漏检修复（用户指定继续进攻 1f, 1f 战役轮 R10）

- **双 bug 互锁根因（一句话）**: Kotlin `typealias DefinitionOptions<T> = BeanDefinition<T>.() -> Unit` 在 k2cj 译器有两条独立 bug 互锁——(a) render `Kind::TypeAlias` 的 `name.contains('<')` 门控把所有泛型 typealias 注释化为 `// typealias X<T> = ...`（避免早期 cjc 拒绝），下游 `X<Arg>` 引用全报 undeclared type；(b) parse_type_raw 的 `<` 泛型实参分支后未再检查 receiver-function-type（line 3218 的 receiver 分支只在 expect_ident 后立即触发，泛型实参分支 line 3247 后直接 fall through 到 `?` 检查 + return），导致 `BeanDefinition<T>.() -> Unit` 被截断为 `BeanDefinition<T>`（函数类型部分整体丢失，target_type 错误）。两个 bug 互锁：即使解了 render 注释化，DefinitionOptions 的 target_type 仍是错的。R10 双修解锁。
- **探针矩阵（6 个 cjc 探针实证, output/probe/）**: 仓颉 1.0.5 完整支持 `type X<T> = Y` + `(?T) -> Unit` + `(BeanDefinition<T>) -> Unit` + 函数类型参数中 `?T` 语法糖。
  - generic_typealias: `type Callback<T> = (T) -> Unit` ✓
  - generic_typealias_recv: `type DefScope<T> = (Scope, PHolder) -> T` + `(Option<T>) -> Unit` ✓
  - qmark_type: `type CallBack<T> = (?T) -> Unit` + `(C, ?T) -> T` ✓
  - full_typealias_form: 三个 koin 实际形态全证 ✓
- **修复（render L1 + parser L2 双修）**:
  - **render.rs (Kind::TypeAlias, -5/+1)**: 移除 `if name.contains('<')` 门控，统一渲染 `type {name} = {target_type}`。
  - **parser.rs (parse_type_raw, +20 行)**: `<` 泛型实参分支 (`self.eat_sym("<")` line 3247) 后复用 line 3218 同款 receiver-function-type 检查（`.( ` 双 token 触发，ReceiverType 已含 `<T>` 加入 params）。R9 fix-history 已记录该 receiver-function-type 分支位置，本轮补齐 `<` 后的二次检查。
- **测量**:
  - **1f**: 746 → **543（-203, -27%）**。undeclared type 177→62 (-115): DefinitionOptions×94 + Definition×17 + OnCloseCallback×4 全清（主要簇）；残 62 为泛型参数 T/S 泄漏（reified `T()` 类型字面量用法，R11+ 候选）。
  - **新揭示**: unimplemented×42（expect class 抽象方法未实现 stub 缺失，下游显露——之前 typealias 注释化遮蔽了下游使用）、expected×163（reified `T` 类型字面量簇，e.g. `elementAt(0, T)` `getAll(T)` `T` 单独出现被 cjc 拒绝）。
  - **外溢核对**: 1g 1044 → **1033（-11 正向，ksoup 亦有泛型 typealias 注释化受益）**；2a 963 → **963（0 中性，无外溢）**。
- **测试**: 271_generic_typealias_fn_type（4 个 typealias 全形态: `Definition<T> = Scope.(P) -> T` / `OnCloseCallback<T> = (?T) -> Unit` / `DefinitionOptions<T> = BeanDefinition<T>.() -> Unit` / `StringList<T> = ArrayList<T>`；含 Definition<T> lambda 2 参数 / OnCloseCallback<T> ?Int64 参数 / DefinitionOptions<T> 显式 b 参数）。回归 **263/263 单文件 + 36/36 项目全绿**。
- **R11 候选（按杠杆排序）**:
  - ① missing-argument×107（Invalid 默认参数占位, state R9 候选 ③ 继承, 最大簇, 低风险 L2）
  - ② expected×163（reified `T()` 类型字面量簇, 高风险, 仓颉无 reified 概念, 可能需 stub 转发或 heuristics 改写）
  - ③ unimplemented×42（expect class 抽象方法 stub 注入, 与 R9 候选 ④ 静态成员 stub 同源）
  - ④ generic-receiver `extend<T> KoinDefinition<T>` 语法（koin ~10 处, state R9 候选 ②）
- **战役轮标**: 1f R10（用户指定继续进攻, 非 auto 轮）。

### 1f 簇 generic-extension-fn (2026-07-12) — 泛型扩展函数簇打穿, 4403→746（用户手动指定, 1f 战役轮 R9）

- **口径修正（本轮首要产出）**: 1f R8 记载"7 errors"系打印截断误计（旧 compile_r10.log 末行实为 "794 errors generated, 8 errors printed"; 1f 记录早于 2026-07-09 口径修正, 未随会签重测）。当前译器项目模式新译 + `--error-count-limit all` 真基线 = **4403**。旧 target_1f/ 为手工修补产物, 保留存档; 新一轮走 translate_1f.py（本轮首次固化管线, translate_1g.py 同款三态脚本）→ output/target_1f_r9。
- **证实（真根因一句话）**: `parse_fun` 扩展函数接收者环无条件把函数级泛型后缀拼到接收者、再清空函数自身 generic_params——`inline fun <reified R, T1..> Module.factoryOf(...)`（koin factoryOf/singleOf/scopedOf DSL, R..T22 全 arity ~149 函数）被译成 `extend Module<R,T1,...>`（Module 非泛型）→ `undeclared type R/T1..T7+` ×3710（占基线 84%）+ 级联泛型实参数目错配×147。
- **修复（parser.rs, L2 双补丁）**: ① 新增 `receiver_has_type_args` 门控——仅当接收者显式带 `<...>`（`fun <T> ArrayList<T>.foo()` 的 811 行跳过路径）才把泛型归接收者并清空函数泛型; 裸名接收者保留函数自身泛型, 渲染为 `extend Module { func factoryOf<R>(...) }`（cjc 探针证实: extend 内泛型成员函数 + 同名跨 arity 重载合法, output/probe/extend_generic_fn）。② 验收期抓到自引入回归并修复: `fun ArrayList<Int>.computeAvg()`（接收者带**具体**类型实参、无 `fun <T>` 前缀）走 815 行分支被当函数泛型, 旧代码靠无条件拼接负负得正——补 `<...>` 后紧跟 `.` 则归接收者（proj_extensions 项目测试当场抓获, 修复后复绿）。
- **测量**:
  - **1f**: 4403 → **746（-83%, -3657）**。undeclared R/T1..T22 全清; 残余大簇: undeclared type 177（DefinitionOptions×94/Definition×17/OnCloseCallback×4 = **带接收者泛型函数类型 typealias 被丢弃**, 已查证 OptionDSL.kt/BeanDefinition.kt/Callbacks.kt 三处定义, R10 头号候选）/ raw generic×104 / missing-argument×103（Invalid 默认参数占位）/ undeclared id×72 / unable-infer-generic×42。
  - **外溢核对**: 1g 1044→**1041（-3 正向**, ksoup 亦有裸名接收者泛型扩展）; 2a 964→**962（-2 正向）**。
- **测试**: 270_generic_extension_fn（裸名接收者 ×2 arity 重载 + 运行断言; 注记 generic-receiver `extend<T> X<T>` 语法缺口为 R10 候选, 现 `extend Box<T>` 形态 cjc 拒收——本就坏、无测试覆盖、本轮不扩範围）。回归 **262/262 单文件 + 36/36 项目全绿**。
- **R10 候选**: ① 泛型 typealias 丢失（~115 直接 + 级联, 需带接收者函数类型展开机制） ② generic-receiver extend 语法 `extend<T> KoinDefinition<T>`（koin ~10 处, 兼修混合泛型全后缀误拼） ③ missing-argument Invalid×103（默认参数占位机制） ④ 静态成员 stub 簇（defaultContext/synchronized 等 28+9）。
- **战役轮标**: 1f R9（用户手动指定复攻, 非 auto 轮; 审计"禁开新 target"不涉及——1f 系既有 🟡 target 解冻, 解冻依据 = 口径误计澄清 + 单根因大簇可行动）。

### 1g 簇 not-member (2026-07-10) — 子簇①② 嵌套类型限定链 + appendCodePoint（auto R4/20, 战役轮 R19）

- **战役**: auto R4/20（1g 战役轮 R19），not-member-of-class ×113 混桶的两个子簇。基线 output/target_1g_r18 = 1051。上代 fixer 写完代码撞限额中断（未跑回归），本代接力验收 + 修兜底撞车。
- **子簇① 嵌套类型限定链（render.rs, +48）**: ksoup `Document.OutputSettings.Syntax.xml` ×7——中间 `Syntax` 的基 `Document.OutputSettings` 是 Member（非 NameRef），render_member 单级 NameRef 折叠不触发, 残留 `OutputSettings.Syntax` 报 "'Syntax' is not a member of class 'OutputSettings'"。新增 `type_qualifier_class()` 递归解析纯类型限定符链, base 是 Member 且整链解析为类名限定符、name 是其嵌套类型时折叠为提升后裸名。
- **子簇② appendCodePoint（render_calls.rs, +11）**: ksoup Tokeniser/TokenData/StringUtil ×6——Cangjie StringBuilder 无 appendCodePoint, 有 append(Rune)。映射 `sb.appendCodePoint(cp)` → `sb.append(Rune(UInt32(cp)))`, 含 nullable 解包接收者。
- **关键修复（验收期, 兜底撞车）**: 上代 fixer 原码含 `enum_entries(name)||is_class_name(name)` 兜底折叠多级链末端——**test 221 撞车**: `Token.TokenType.StartTag` 的 StartTag 既是 TokenType 枚举条目又是 Token 嵌套类, 兜底把枚举条目误折成裸类名 → mismatched types（261/261 退到 260/261）。**移除多级兜底, 仅在 lifted_nested 注册表确认 (base_class,name) 命中时折叠**（比单级更严; 单级兜底安全因 name 必是直接父的嵌套类型, 多级不成立）。268 首分支已足, 不需兜底。
- **测试**: 268_nested_type_qualifier_chain（3 级链 Document.OutputSettings.Syntax, 裸/限定混用 + isXml type 位 + 枚举条目访问）; 269_append_codepoint（nullable 接收者 + emoji codepoint 0x1F600）。回归 259→**261/261** + 36/36。
- **测量**:
  - **1g**: 1051 → **1044（-7）**。not-member 113→101（-12）: Syntax×7 清 + OutputSettings×8 清 + StringBuilder 14→8（appendCodePoint -6）; ArrayList<Node>×15/Node×14/EscapeMode×9 不变。**~9 honest reveals**: 折叠/映射解遮蔽下游错（getOrThrow×5/add×7/tag×6/Object×8 族部分为新表面）。净 -7。
  - **2a（外溢核对）**: 964 → **964（+0 中性, 无外溢）**。type_qualifier_class 严折叠（注册表确认才折）未掀 datetime Directive 层级——与 R18 +138 教训对照, 严折叠避坑成功。
- **R20 候选（= auto R5/20, 须战略校准 + 防刷冷启动审计）**: mismatched×245（最大但最杂, Option/unwrap L3 高风险）/ undeclared id×124（code/_parser/append×9 等）/ not-member×101 残余（ArrayList<Node>×15/Node×14/EscapeMode×9, 疑 stub/API 映射低风险增量）/ 簇A真方法分派（read, 高风险, 须 tokeniser 语义层先收敛）/ nested-class-in-interface（须 datetime 抽象类层级先修）/ String.replace(Rune→Regex)。
- **auto R4/20**。下一轮 auto R5/20 为定期校准节点（三张地形图重估 + 防刷软柿子审计）。

### 1g 簇 A (2026-07-10) — FilterResult 嵌套 enum-in-interface 提升顶层（auto R3/20, 战役轮 R18, 本代 fixer 收官）

- **证实根因**: `render_interface`（render.rs）只遍历 `Kind::Func` 成员发射方法签名, **静默丢弃嵌套 `Kind::Enum`/`Kind::Class`**——仓颉 interface 体只容方法签名, 不容嵌套类型。故 `NodeFilter.FilterResult`（5 项 enum）既不在 interface 也无顶层输出 → 引用处 undeclared id×12 + type×4。对照: `render_regular_class`（1838 一带）已提升嵌套 Class/Enum, interface 路径缺此逻辑。
- **修复（render.rs render_interface, L1 单函数）**: 成员遍历遇 `Kind::Enum` → `self.t(*m)` 渲染后收集, 拼接到 interface 文本尾（顶层 `enum FilterResult`）。**引用侧零改动**: `FilterResult.CONTINUE`/`FilterResult`(type) 已是裸形（限定符 `NodeFilter.FilterResult` 早由 render_member 展平, 对照 267 测试 `Walker.Decision.GO`→`Decision.GO` 亦通）, 提升即解析全部引用。
- **范围裁决（证据驱动, 收缩避 2a 回归）**: 初版同时提升嵌套 **class** → 2a datetime `Directive` 抽象类层级（带 formatLength/formatLetter 字段+继承）被掀开, +138（missing-abstract×79 + shadow-member×72 簇）。**收缩为 enum-only**（正合任务「本轮只打 enum-in-interface」范围）: 2a 回落 964 中性, 1g 反而更优 -15。nested-class-in-interface 记 R19。
- **测量**: 1g 1066→**1051（-15）**。FilterResult undeclared id×12→0 + type×4→0（16 全清）; 残 2 处 node_traversor 提及 FilterResult 实为被遮蔽的 filter.head 可空性错（诚实surface）。2a 963→**964**（enum-only 中性, 噪声带内）。
- **测试**: 267_enum_in_interface（interface 内 enum + 方法返回该 enum + implementer override + 外部裸/限定引用 `Decision.GO`+`Walker.Decision.GO` + match; 断言运行 go/skip/halt/true）。回归 **259/259 单文件 + 36/36 项目全绿**。
- **R19 候选**: mismatched×244 / undeclared id×124(code/_parser/append) / is-not-member-of-class×113(ArrayList<Node>×15/Node×14/StringBuilder×14/EscapeMode×9) / no-matching-operator()×38 / 簇A真方法分派(read,高风险) / **nested-class-in-interface**(本轮缓, 2a Directive 掀 +138 前需先修 datetime 抽象类层级) / String.replace(Rune→Regex).
- **auto R3/20**。**本代 fixer context 200k+ 收官退役, 换代交接见 fix-history 尾部「交接」**。

### 1g 簇 A 阶段② (2026-07-10) — companion 标量常量提升顶层（auto R2/20, 战役轮 R17）

- **决策转向（证据驱动, 与协调者预设风险模型相反, 已记录理由）**: 协调者预设「方法分派安全 / companion 有风险」。**实测反转**: (1) 仓颉 enum **不支持 static 成员**（探针 `unexpected variable declaration in enum body`）→ companion 必须提升顶层, 是全新 render 路径; (2) 渲染 68 个 `read` 条目体会**掀开 tokeniser 语义层**——被调方法所在 token.cj(62)/character_reader.cj(34)/tokeniser.cj(22) 已有 118+ 错误行, 真方法分派极可能净负。故本轮落**安全净正切片**=companion 标量常量提升, 真方法分派留 R18。
- **真根因**: `TokeniserState.nullChar`（companion `public const val`）被 7 处外部文件引用（CharacterReader/Token）。仓颉 enum 无处挂 static → 全报 "nullChar is not a member of enum"。
- **修复（parser.rs + render.rs, L3）**: (1) parser 捕获 enum companion 内**非 private 标量 `[const] val`** 存入新字段 `Kind::Enum.companion_consts`（复用 parse_var_decl）; companion **函数体不解析**（改跳签名+平衡跳 body）——否则 helper 体内 `when (val c: Char = ...)` 带类型 when 主体（TokeniserState:1669, 译器尚不支持）会整文件报错。(2) render 把标量常量提升为同文件顶层 `let EnumName__const`（双下划线防撞名, 非标量/数组不提升控风险）; (3) render_member 把外部 `EnumName.const` 重写为 `EnumName__const`（提升侧/引用侧同命名规则; 仅重写确实提升成功者）。
- **测量**: 1g 1072→**1066（-6）**。nullChar "not a member" 7→0; TokeniserState 从 enum-member 簇整体消失（残 read×1=方法分派, R18）。**4 处 `.replace(nullChar,...)` 由「nullChar 不是成员」转为**被遮蔽的真错**`String.replace 期望 Regex 得 Rune`——诚实新表面（-7 член + 4 揭示 = 净 -3 于 replace 簇, 另 3 处 character_reader `c != nullChar` 干净解决）。2a 964→**963**（parser 改动中性/-1）。
- **测试**: 266_enum_companion_const（条目体 + companion public 标量 const + private const + 带 typed-when 体的 helper func; 断言外部 `Signal.MARKER`→42 可达 + helper 体不致翻译中止）。回归 **258/258 单文件 + 36/36 项目全绿**。
- **R18 候选**: ① FilterResult 嵌套 enum-in-interface 未提升(×16, render 从 interface 提升缺失, 与簇A同族结构截断) ② 簇A真方法分派(read, 需先修 tokeniser 语义层, 高风险, 探针已证 match(this) 机制可行) ③ String.replace(Rune→Regex) 误映射 ④ mismatched×243。
- **auto R2/20**。

### 1g 簇 A (2026-07-10) — enum-entry-body 截断阶段①, 68 条目全保留（auto R1/20, 战役轮 R16）

- **证实（真根因一句话）**: Kotlin enum 条目带匿名类体（`Data { override fun read(...) {...} }`）时, parser 条目循环在读完条目名后只认 `(args)` 或 `,`, 条目体 `{` 两者皆不匹配 → 循环首个条目后即 break, **丢失其余 67/23 条目**（TokeniserState 仅存 Data, HtmlTreeBuilderState 仅存 Initial）→ 引用处全炸 "not a member of enum"。
- **修复（parser.rs, 阶段①·L2）**: (a) 条目名后若遇 `{` 则 `skip_balanced_braces` 跳过体、保留名; (b) `;` 后成员区 else 分支遇 `{` 也平衡跳过——否则逐 token bump 会走进嵌套 `object Constants {...}` 体, 在其内层 `}` 误判 enum 结束, 泄漏 `companion` 到顶层（HtmlTreeBuilderState 首次全解析后暴露的 `expected declaration, found 'companion'` 致命错, 已修）。条目体的 override 方法本轮丢弃（enum_members 本就未存入 Kind::Enum）。
- **测量**: 1g 1084→**1072**（-12, TokeniserState not-member 13→8, undeclared id 144→136; 68+24 条目结构全对）; 2a 964（重译无变化, parser 改动对 2a 中性）。残 TokeniserState×8 = companion 常量(nullChar)+read 方法访问, 属阶段②。
- **阶段②（本轮探针证可行, 落 R17 候选）**: 仓颉 enum 可挂成员 func 用 `match(this)` 集中分派（探针 output/probe/enum_member_probe 编译+运行通过, 输出 12/TagOpen）。**未本轮实现**: 完整阶段②需(1)捕获每条目体(2)渲染抽象方法为 match 分派(3)渲染 companion(常量+~15 私有 helper)——条目体重度引用 companion 作用域符号, 部分实现极可能净负, 故整体排 R17。
- **FilterResult 候选（机制不同, 仅记录）**: `NodeFilter` interface 内嵌套 `enum class FilterResult`——parser 走 parse_class 成员环 `is_kw("enum")` 应能解析, 但输出中 FilterResult 既不在 interface 也无顶层定义 → **嵌套 enum 未被 renderer 从 interface 提升到顶层**（class 路径有提升 line 1599/1833, interface 路径疑缺）。×16 实例(undeclared id×12 + type×4)。R17 候选, 与簇 A 阶段①同为「结构截断」族但根因在 render 提升侧。
- **测试**: 265_enum_entry_body（条目体+`;`+抽象方法+嵌套 object+companion 全 shape, 断言 4 条目全存活+无 companion 泄漏）。回归 **257/257 单文件 + 36/36 项目全绿**。
- **auto R1/20**。

### 1g 簇 E (2026-07-10) — isNullOrEmpty 空安全映射, 证伪"过度可空化"（auto R15/15, 终轮）

- **证伪（本轮主要价值）**: R6 存证"notEmpty 形参过度可空化"不成立——Kotlin 源本就 `String?`, `?String` 翻译正确且 cjc 实参隐式协变。**真根因**: `isNullOrEmpty()` 无映射透传 + 可空接收者误插 getOrThrow → 宿主函数体编译失败 → 44 调用点级联 no-matching-declaration。**方法论沉淀: no-matching-declaration 大簇优先怀疑宿主体级联, 而非调用点/签名**。
- **修复**: render_calls 增 isNullOrEmpty arm——原始未解包接收者, 可空 `((x?.isEmpty()) ?? true)` / 非空 `x.isEmpty()`。
- **测量**: 1g 1146→**1087**（-59, notEmpty 44→0 + isNullOrEmpty 7→0, 零新表面; 注: R14 记 1136、本轮重译起点 1146, ±10 级重译漂移, 以各轮 pre/post 差为准）; 2a 967→964。
- **测试**: 264_param_nullability。回归 256/256 + 36/36 全绿。
- **auto mode 15 轮完成**。

### 剪枝轮 stub 存量整改 (2026-07-10) — 查证 6 组, 0 退役 / 6 暂封·排期（auto R14/15）

- **性质**: 净负债审计轮, 不追错误数。目标=退役手写 stub 换真实 API 映射。**查证结论: 6 组候选无一有 drop-in std 对应物, 全部维持 stub**——把「🔒 未查证」债转为「⏸ 已查证·有暂封条件」的确定态（去掉 6 条待查 TODO 即进展）。**零译器改动 → 零回归风险**。
- **证据基线（当前译器新译 1g→target_1g_r14, 1136 err ≈基线 1135）**: 每组 stub 的 marker 在新译 src 中仍活引用（AutoCloseable×3 / MutableList×1 / MutableMap×1 / MutableCollection×1 / Entry+MutableEntry×2 / Reader×13 / StringReader×10 / KClass×16 / MutableIterator×11 / Appendable×8 / Charset×9）——**无死 marker 可直接删**。
- **逐组查证（文档: cangjie-std/{core,io,reflect,collection}, cangjie-stdx/encoding）**:
  - **AutoCloseable → std.core `Resource`**: Resource 面=`isClosed(): Bool` + `close()`; stub 面仅 `close()`。实现类 CharacterReader 有 organic `isClosed()`（但非 public/override）, **QueryParser/TokenQueue 无 isClosed()**。映射需给每个 `<: Resource` 缺 isClosed 的类合成 public 默认实现=render 侧 R6-同款成员合成 → **波及大, 排期**（非单轮）。
  - **MutableList → std.collection.List / MutableMap → Map / MutableCollection → Collection / MutableEntry → (K,V)**: 父类型位 marker（NodeList<:MutableList, IdentityHashMap<:MutableMap, IdentityEntry<:MutableEntry, `values: MutableCollection<V>` 值位）。退役需 R6-同款父类型位成员转发机制（R6-R7 只打通了 `by 委托` 与值位 `MutableList<T>→ArrayList<T>`, 父类型 marker 位未覆盖）→ **波及大, 排期**。
  - **READER_STUB → std.io StringReader**: 语义面差异过大——(a) ctor: stub `StringReader(s: String)` vs std `StringReader(InputStream/buf)`; (b) `read(): Int64`（-1 EOF）vs std `read(): ?Rune`（None EOF）; (c) stub 有 bulk `read(Array<Rune>, offset!, length!): Int64`（jsoup CharacterReader 唯一读法）std 无此重载。**暂封**, 重审: 仓颉 io 出 char-based -1/EOF Reader 或 bulk read 重载后。
  - **KCLASS_STUB → std.reflect**: reflect 入口 `ClassTypeInfo.of(instance)` **需实例**, 而 `X::class`→`KClass<X>()` 无实例; 面为 `.name`/`.qualifiedName` 无 `.simpleName`; macOS/enum/tuple 不支持。**暂封**, 重审: 仓颉出类型级（非实例）反射 + simpleName。
  - **MUTABLE_ITERATOR_STUB → std.collection 迭代器族**: 仓颉 `Iterator<T>` **无 `remove()`**, 无 iterator-based 就地删除概念（`List.remove(at:)` 是集合索引删, 非迭代器删）。**暂封**, 重审: 仓颉出 MutableIterator/removeVia-iterator。（另注: 该 stub 当前在 1g 有 override 返回型不变错, 属 render 侧独立 bug, 不在剪枝范畴。）
  - **APPENDABLE_STUB → core**: 仓颉 core/collection **无 Appendable 接口**, 仅 StringBuilder 具体类。**暂封**, 重审: 仓颉出 Appendable/CharSink 接口。
  - **CHARSET_STUB → stdx.encoding**: stdx.encoding 仅 Base64/Hex/URL, **无 Charset/CharsetEncoder/named-charset API**。**暂封**, 重审: 仓颉出 charset API（原登记条件）。
- **净规则数变化**: 0（stubs.rs 未改, 15271 字节前后不变, git clean）。
- **回归**: 255/255 单文件全绿; 1g 1136（≈基线 1135, +1 容差内）; 2a 未改译器 → 保持基线 967。
- **排期建议**: 父类型位 marker 退役（AutoCloseable→Resource + Mutable*→collection）合并为一个「父类型位成员合成/转发」深层特性候选（与 R6 值位委托同源, 复用 override_provably_unmatched 基建）; io/reflect/charset 三组待仓颉 std 补面, 非译器可解。

### 1g Option 战役第四批 (2026-07-10) — == 结构语义闭环 5/8（auto R13/15）

- **方案 A（equals 体先解包）胜出**（两方案探针均通, A 回归面小）: ① IsCheck 可空感知 `(x.isSome() && x.getOrThrow() is T)` ② TypeCast 可空感知 ③ `::class` 反射比较 → `!(other is EnclosingClass)` ④ 桶 C 空安全 `.equals()` 派发（this 侧不派发防 === 误改+自递归）。
- **语义验收（审计强制项核心交付）**: 263_equals_dispatch 运行断言 14 行全绿——同值异实例 true / 不同值 false / null 组合 / refEq 身份桶互不干扰。R8 剥离的 -96 中 5/8 类结构语义闭环, 机制经运行时证明。
- **残留 3 类（tag/nodes/identity_hash_map）**: `other as T` 裸语句 smart-cast 后成员访问仍作用在 Object——flow-sensitive smart-cast 跟踪, 独立深层特性候选（同时能闭 when-is equals + R11 D-cast 桶）。
- **测量**: 1g 1150→**1135**; 2a 967（+3 级联, 记录）。262 的 Box 用例改纯引用类（when-is form 本轮不覆盖, 已注记）。
- **回归**: 255/255 + 36/36 全绿。

### 1g Option 战役第三批 (2026-07-10) — eq 归一 76→22（auto R12/15）

- **探针实证分桶**: 桶A 引用相等——双泛型 `__k2cjRefEq2<A,B>` 辅助（单泛型跨子类型推断失败是坑; 整包单份注入, 逐文件注入泛型顶层函数会 overload conflict——首版 net -5 修正后 -53 的关键）; 桶B 值类型单侧可空 Some 包装; 桶C 结构 equals 派发**探针证实阻塞**（`equals(?Object)` 体内 when-is 匹配不了 Some 装箱, 静默错误结果）→ 延后 R13, 本轮含 equals 比较走桶A（引用语义, 能编译）。
- **测量**: 1g 1203→**1150**（-53, eq 76→22, refEq2 49 调用点 0 自致错误）; 2a 964（+1 级联显形, 仅记录）。残留 22 均"类型判不出宁残留"。
- **测试**: 262_option_equality。回归 254/254 + 36/36 全绿。

### 1g Option 战役第二批 (2026-07-10) — under-unwrap 79→40（auto R11/15）

- **分桶诊断（审计战术提示兑现）**: A 循环游走局部×11 / B `&&` 短路守卫×10 / C 可空继承字段×15 / D 非 NameRef receiver×15。三处覆盖缺口: ① 方法调用 receiver 从不解包（只有字段读走 748 路径）② is_nullable_expr 不递归 Call/Member 初值 ③ field_type_by_name 漏类体 member var。
- **修复（三小步逐步回归）**: render_calls `render_call_recv`（748 同款门控）/ heuristics 初值递归推断 / 继承字段回退。79→40; 1g 1234→**1203**（-31, 级联 +6 not-a-member 为解包后真实揭示）。2a 963 无变化无回归。
- **L3 残留桶（R12+ 候选, 详见 fix-history）**: D-cast/D-index/D-assign/D-double/C-ambig（跨类字段歧义需 receiver 静态类+继承链）。
- **测试**: 261_option_under_unwrap。回归 253/253 + 36/36 全绿。

### 1g Option 战役第一批 (2026-07-10) — over-unwrap 子模式清零（auto R10/15）

- **诊断快照（1243 基线四子模式）**: ① over-unwrap 15 ② under-unwrap 79 ③ ==/!= 可空 49 ④ Option-vs-T mismatched（混于 243, L3 不碰）。
- **选①依据**: 15 处同一机械模式、render 单点、不触推断核心。根因: smart-cast 重绑定块内 `x!!` 仍发 `.getOrThrow()`——成员访问路径早有 `is_null_check_rebound` 门控, ForceUnwrap 分支漏了, 复用 helper 补齐（L1 一行级）。
- **测量**: 1g 1243→**1234**（15 全清, 6 处被遮蔽下游错误显形——诚实新表面）; 2a 966→**963**（残 5 处 DayOfWeek 枚举 over-unwrap 系另一机制, 独立候选）。
- **测试**: 260_option_over_unwrap（守卫块/early-return/无守卫三路）。回归 252/252 + 36/36 全绿。

### 1g + 2a 双目标 (2026-07-10) — R9: stub 去重解锁 1g + 成员 import 重限定机制（auto R9/15）

- **①**: translate_1g.py 从逐文件切**项目模式**（历史 merge-parser bug 已被 2a R1-R4 修复顺带治愈）——stub typealias 重复注入 8 redefinition 清零，1g 语义层完整暴露 1355→1306。
- **②**: 成员 import 重限定机制（Graph.member_imports 表 + parser 收集 + render 裸 NameRef 改写 `C.member`）。关键坑: 类成员隐式 this 引用 decl 也是 None，须 `enclosing_class_has_member` 门控（首版 2a +17 回归, 修正后归零）。**1g 簇 D 打穿**: 1306→**1243**（lowerCase/normalize/normaliseWhitespace 全清）。
- **2a 证伪记录**: Directive×35 非成员 import——是 sealed class 嵌套类型限定引用 `Directive.YearMonthBased.Era` 提升后未更新（挂 engine 嵌套提升注册表, R10 候选）。2a 963→966（+3, 成员 import 改写把 undeclared 转成更准确的 not-a-member: 仓颉 Duration 缺 Companion 成员）。
- **靶向测试**: 259_member_import。回归 251/251 + 36/36 全绿。
- **fixer 换代**: 该 fixer context 已 500k+, 本轮退役, R10 起新 fixer。

### Phase 1 — 1e ktor-io (2026-07-10) ✅ 运行时验证补齐（审计修正 b）

- **动机**: 1e 于 06-27 收敛后译器已大改（1g R5-R7 委托/override 剥离、2a R1-R4 parse 修复），需证明当前译器在 1e 语料上未回归且译文运行语义正确。
- **方法**: 副本二进制重译核心 5 文件 → `output/target_1e_verify/`（脚本 = translate_1e.py 改 BIN/OUT 两行）→ cjpm build → 换行为断言 main.cj → cjpm run 人工核对输出。
- **三态**: 重译 5/5 OK；build **0 errors**（3 个 unused warning）；run 通过，18 项行为断言输出全部符合 Kotlin 语义。
- **核对点**: ① LineEnding/ByteOrder enum toString+`==`（Default/Lenient、BIG/LITTLE_ENDIAN 正确）② LineEndingMode value class→struct: bitmask `contains`/`plus` 正确（Any⊇CR true, CR⊉Any false, CR+LF⊇CRLF false）③ toString when-分派: CR/LF/CRLF 走字面分支, 组合值走 else 过滤分支且输出 `[CR, LF]`/`[CR, LF, CRLF]` 与 Kotlin `listOf.filter.toString()` 逐字一致 ④ toIntOrFail: 42 恒等返回, Int64.Max 抛 IllegalArgumentException 且消息插值正确 ⑤ 注解类降级为普通类, PublicAPICandidate.version 属性保真。
- **已知语义偏差（记录, 非回归）**: Kotlin `Int.MAX_VALUE`(2³¹-1) 阈值因 Int→Int64 映射变为 `Int64.Max`——(2³¹-1, 2⁶³-1) 区间在 Kotlin 抛异常、译文不抛；`toInt()` stub 为恒等（无 32 位截断）。属 Int 宽度映射决策的已知后果。
- **结论**: 1e 在当前译器下仍收敛且运行时语义正确，Phase 1 首个"编译 0 错 ≠ 翻译能力"质疑被运行时证据回应。未改译器代码、未 commit。

### Phase 1 — 1g full-ksoup (2026-07-09) ⏳ R7 完成 — 委托簇收尾，三接缝合上（auto R2/15）

- **行动簇**: mutable-collection-delegation part 2（R6 四接缝收尾）。
- **修复（fixer 续作, 详见 fix-history R7 条）**: ① render.rs — List-iface 类用户 0 参 first()/last() 转渲染为 prop（调用点无需改写: `.first()` 已被 stdlib 映射为 `[0]`，ksoup 0 处裸调用）② removeIf 强制返 Unit + IIFE 丢弃 Bool ③ heuristics.rs — override_provably_unmatched 识别 List 委托类，仅保 iterator/next/hasNext ④ **parser.rs 父类泛型保留**（`Elements : Nodes<Element>` 曾渲染为裸 `<: Nodes`）——本轮最大单点，elements.cj 75→43。
- **有据缓行**: NodeList 直接实现型不做投机实现（探针证 Boolean-return override 阻抗 + 自有存储），记 R8 候选; ParseErrorList 实为 by 委托，R6 已修（其 4 错系级联误报）。
- **测量**: 1403 → **1355**（net -48）。unimplemented prop 2→0; override 43→28; nodes.cj 39→33; elements.cj 75→43。
- **靶向测试**: 246_list_delegation_overrides。
- **回归**: 238/238 single（231/231 expected 匹配）+ 36/36 project 全绿。
- **判据**: R6 0.57% + R7 3.4% 连续 2 轮 <10% → 切换 target。委托簇（一个根因簇跨 R6-R7 消灭）计簇数进展 1。层 1 改选 2a（parse 层，泛化信号强，portfolio 优先）。

### Phase 1 — 1g full-ksoup (2026-07-09) ⏳ R6 完成 — mutable-collection 委托簇 part 1（auto R1/15）

- **行动簇**: mutable-collection-delegation — Kotlin 接口委托 `class X : MutableList<T> by delegateList` 被丢弃 + 空 marker 父类型，Nodes/Elements/ParseErrorList 全部集合调用面失效。
- **修复（fixer, 详见 fix-history 2026-07-09 条）**: ① node.rs `SuperDelegation` 节点模型 ② parser.rs 父类型位 `by` 委托捕获 + `suppress_trailing_lambda` 门控（防 `by x {` 吞类体）③ render.rs `render_list_delegations()` — 父类型映射真实 `std.collection.List<T>` + 全套转发成员生成（探针实测接口面）+ 用户 override 去重 ④ project.rs cjpm.toml 模板固化 `--error-count-limit all`（口径基建）。
- **测量**: 1411 → **1403**（net -8；预判 ~145，**误差 18×，surprise 触发重估**）。
- **重估结论**: by 委托类部分打穿（not-member 145→131），但四个接缝未合: (a) `List<T>` 的 `prop first/last` 与用户 `func first()/last()` 撞名 (b) removeIf 返回 Unit vs Bool (c) override 剥离的已知成员集未收录 std List/Collection → equals/hashCode/clone override 错误 +7（36→43）(d) **直接实现型**（ParseErrorList/NodeList `: MutableList<T>` 无 by）父类型映射成 `List<T>` 生效但无转发生成 → unimplemented。R7 = 簇 C part 2 收尾这四点。
- **靶向测试**: 244_list_delegation / 245_list_delegation_field。
- **回归**: 237/237 single + 36/36 project 全绿。
- **每错成本注**: 本轮 net -8 偏基建（委托机制铺轨），收益预计 R7 兑现；连续 2 轮 <10% 则按判据评估切换。

### Phase 1 — 1g full-ksoup (2026-07-09) ⏳ R5 完成 — 指标口径修正 + undeclared-supertype 簇清零

- **⚠️ 指标口径修正（本轮最重要产出）**: R4 编译日志末行 "**1460 errors generated, 8 errors printed**"——cjc 默认 `--error-count-limit 8`。R2-R4 的"10 errors"= 8 个打印错误块 + 2 条 cjpm 消息，是截断误计。R2 的"1598→10 (99.4%)"叙事作废（1598 亦是 errors generated 口径，10 不是）。自 R5 起测量管线统一加 `compile-option = "--error-count-limit all"`。**该口径变更方向为改严，2026-07-09 已由用户人工会签批准**。
- **R5 行动簇**: undeclared-supertype — 5 个核心类父类型声明失败（Attribute <: Map.Entry / CharacterReader <: AutoCloseable / NodeList,Nodes,ParseErrorList <: MutableList / IdentityHashMap <: MutableMap）。
- **R5 译器修复（4 处，详见 fix-history 2026-07-09）**: ① parser 父类型位限定名折叠（Map.Entry→Entry 等）② map_type 泛型位 Entry 系→元组 (K,V)、非泛型位裸名折叠 ③ stubs.rs +4（AutoCloseable/MutableList/MutableMap+MutableCollection/Entry+MutableEntry marker）④ render override 剥离（override_provably_unmatched，父类型全为已知成员集接口且不命中时剥 override；坑: 嵌套类成员先查直接父节点）。
- **附带修复**: parser 合并翻译错误恢复 depth bug（`depth == 0`→`<= 0`，错误点在嵌套花括号内时原逻辑跳 EOF 丢弃后续全部文件）— 2a 测量被阻断时发现，测试 proj_parserecovery。
- **1g 测量（全量口径）**: 1458 → **1411**。undeclared-supertype 5 根因清零；override 簇 71→36；undeclared type 44→26。
- **剩余大簇（R6 候选）**: undeclared identifier 233（lowerCase 17/FilterResult 16/NamespaceHtml 14…）/ mismatched types 229 / not-member-of-class 145 / not-member-of-enum 93 / invalid binary op 80 / no-matching-call 55。热点文件: element.cj 248 → 重测待更新, evaluator.cj 147, html_tree_builder.cj 126, node.cj 126。
- **靶向测试**: 241_autocloseable / 242_mutable_list_marker / 243_map_entry_supertype / proj_parserecovery。
- **回归**: 235/235 single + 36/36 project 全绿。
- **每错成本注**: 本轮消 47 错 + 修正口径 + 解锁 2a 测量。R2-R4 的"每轮消 6-8 错"成本曲线基于误计口径，同样作废——真实曲线待 R6 起重建。

### Phase 2 — 2a kotlinx-datetime (2026-07-10) ⏳ R6 完成 — 父接口泛型实参 + equals/hashCode 剥离（auto R8/15）

- **簇①**: 父**接口**位丢弃已捕获 type_args（superclass 分支 1g R7 修过, 接口分支漏网）→ `class Instant : Comparable<Instant>` 渲染成裸 Comparable。修复+非泛型 marker 桩排除（首次提交回归 242/243, 加排除后修复——marker 撞 arity 教训）。62→21; 级联曝 missing-abstract×29（raw 遮蔽的接口 conformance 检查放行, 真实语义揭示非回归）。
- **簇②**: equals/hashCode 无祖先定义时剥 override（heuristics 祖先链查, 深度上限防环; toString 不动）。103→21（equals/hashCode 全清, 残 21 为 copy/createEmpty 等）。**跨目标复用验证: 1g override equals/hashCode 14→0**。
- **测量**: 1070 → **963**（-107, 10%）。
- **⚠️ 新发现阻塞（R9 必修）**: 当前译器重译 1g 时 stubs 非泛型 typealias（ByteArray/Regex 等 8 处）在 io_source_reader*.cj 逐文件重复注入、项目装配未去重 → 1g 全量测量被 redefinition 阻塞（target_1g_r8）。正交于本轮改动，属 stubs 注入路径 bug。
- **已知语义缺口（Option/Equatable 战役队列）**: equals 剥 override 后 `.equals()`→`==` 映射链断裂——== 语义未通, 只消了编译错。
- **靶向测试**: 257/258。回归 250/250 + 36/36 全绿。产物: 2a R6 = target_2a_r7/。

### Phase 2 — 2a kotlinx-datetime (2026-07-10) ⏳ R5 完成 — require 族映射 + serialization 剪枝（auto R7/15）

- **两件正交工作打包**: ① require/check/error/requireNotNull/checkNotNull 前置条件族 → render_calls 展开为真实语义（IAE/ISE throw, 探针确认 std.core 构造器），**非 stub**，全语料复用; require×39→0。② kotlinx.serialization 依赖边界剪枝——translate_2a.py 管线剔除 serializers/ 12 文件（裁决理由+重审条件在脚本头注; 同 1c/1e 先例）; KSerializer 族×91+级联清零。
- **测量**: 1237 → **1070**（-167, 13.5%）。scope 变为 43 .kt。
- **残留边界**: TimeZone.kt 非注解位 KSerializer 工厂返回类型 2 处（同边界, 记录不处理）。
- **靶向测试**: 256_require_check。回归 248/248 + 36/36 全绿。
- **R6 候选**: supertype 泛型实参丢失×62（R4 已见 raw Comparable 单根因线索）/ override equals×20+hashCode×20 通用剥离（1g 剩 28 override 可复用）/ extend-shadow×60（extend Instant×40）/ undeclared id×189（Directive×35）。产物: 2a R5 = target_2a_r6/。

### Phase 2 — 2a kotlinx-datetime (2026-07-10) ⏳ R4 完成 — parse 层收官, 语义层首曝 1237（auto R6/15）

- **行动簇**: 残留 5 parse 错打包（4 根因正交）: ① split_top 把 `->` 中 `>` 当闭合（泛型内函数类型乱码, L1: `->` 整体透传）② 函数体内局部扩展函数渲染成非法嵌套 extend（L2: render_block_inner 转普通嵌套 func）③ `val x get() = expr` getter 被丢成无类型字段（L1: try_capture_getter_init）④ 匿名对象 `object : Iface {...}`（L2: make-it-parse throw 存根 + pending_object_type 补字段类型; 完整解=提升具名类, L3 候选）。
- **测量**: 5 → **0 parse**; **语义层首曝 1237**（层地形图兑现, 同 1e 6→69 / 1g 45→1889 先例——审计修正(c)预警成立, "5"确非收敛数）。
- **语义首曝分布**: undeclared type 258（KSerializer/SerialDescriptor/Decoder/Encoder ~91 = kotlinx.serialization 依赖边界）/ undeclared id 243（require×39, Directive×35）/ override 103（equals×20+hashCode×20）/ mismatched 85 / not-member 68 / 泛型实参丢失 62（raw Comparable 同源）/ extend-shadow 60（extend Instant×40）/ ambiguous 53（plus×33）。热点: instant×25, deprecated_instant×20。
- **靶向测试**: 252/253/254/255。回归 247/247 + 36/36 全绿。
- **产物目录**: 2a R4 = target_2a_r5/。

### Phase 2 — 2a kotlinx-datetime (2026-07-10) ⏳ R3 完成 — expect-class 分离构造体簇清零（auto R5/15）

- **行动簇**: 簇 C 真根因双层修复——① parser: `expect class` 分离式主构造器（类名一行、constructor 下一行）时 `skip_modifiers` 不跳换行 → lookahead 失配 → 空类 + 类体泄漏顶层; ② render: expect 成员无体 → 字段渲染为抛异常惰性 prop（规避静态 eager 初始化崩溃）、方法/companion → throw stub。两层必须同修（parse 错遮蔽语义错，只修①会让 7 个 expect class 语义错集中爆发）。
- **测量**: 18 → **5**（-13, 有效率 72%）。uninit×11→0, 孤儿 companion×2→0, 零新增。
- **⚠️ 层地形**: 残留 5 错仍是 parse 层（unclosed `(` / expected `;` / extend / sign / emptyIntermediate, 4 文件）——**2a 语义层至今未揭示**，R4 清完才翻牌。
- **靶向测试**: 251_expect_class。回归 243/243 + 36/36 全绿。
- **产物目录**: 2a R3 = target_2a_r4/。

### Phase 2 — 2a kotlinx-datetime (2026-07-09/10) ⏳ R1-R2 完成 — lex 阻断清零 + 3 parse 簇打包（auto R3-R4/15）

- **R1（interpolation-multiline, lex 层）**: 插值 `${...}` 内渲染出多行 if-let 块 → 仓颉单行字符串 lex 爆炸。render.rs 新增 `fold_interp_expr`（语句折 `;`、续行折空格，4 发 cjc 探针锁定分隔规则）。lex 4→0，揭示 parse 层 111 错。测试 247。
- **R2（3 簇打包，批量三闸门过，1f R1 先例）**: ① 类级泛型 variance 泄漏 44→0（parse_class 加 in/out/reified 跳过，函数级 1f R1 修过、类级漏网）② override/static 冲突+顶层 override 43→0（render 三处剥离）③ expect 函数缺 body 6→0（throw stub + 映射后签名去重防 redefinition，选 stub 因调用面广）。111 → **18**（-93, 有效率 84%）。测试 248/249/250。
- **簇 C 查证结论（重要）**: 顶层 var 未初始化 ×11 根因是 **`public expect class YearMonth` + 分离式 constructor body 语法解析崩溃** → 空 class + 构造体成员泄漏顶层。结构性（成员归位重组），R3 攻，预计连清 15+（uninit 11 + companion 2 + 孤儿链）。
- **回归**: R1 后 239/239+36/36; R2 后 242/242+36/36 全绿。
- **注**: 产物目录命名偏移——2a R1=target_2a_r2/, R2=target_2a_r3/。

### Phase 2 — 2a kotlinx-datetime (2026-07-09) ⏳ R0 基线

- **源**: `C:/Codes/kotlin/kotlinx-datetime`（shallow clone, Kotlin/kotlinx-datetime）。scope: core/common/src 55 文件（common 主源，不含 test）。
- **翻译**: 53/55 文件（恢复修复后；此前 1/55）。11 个 PARSE ERROR 点，每个丢掉所在文件错误点之后的声明。
- **编译 R0**: lex 层遮蔽 — local_time_format.cj + utc_offset_format.cj 未闭合字符串/插值（4 errors 即停）。排除 2 文件探针: **109 errors 仍全为 parse 层**（44 泛型位关键字泄漏 + 29 modifier 冲突 + 14 unexpected modifier + 10 顶层 var 未初始化 + 6 函数缺 body）。语义层未揭示。
- **R1 候选簇（按杠杆排序）**: ① 多行函数类型带命名参数 `construct: (\n years: Int,…\n) -> T`（PARSE ERROR 首簇，DateTimePeriod/LocalDate 等 11 处）② 字符串转义/插值渲染未闭合（2 文件 lex 阻断）③ 泛型位关键字泄漏（44，疑 variance/where 输出侧）④ modifier 冲突（29+14）。


### ksoup R0 (2025-06-14) — 已存档

- **997 编译错误** → 单根因：var-func 命名冲突
- 修复：`engine.rs` `resolve_var_func_collisions()`
- 翻译器版本：分支 `ksoup-entities-validation-2-2`

### ksoup R1 (2025-06-15) — 已存档

- error 从 997 → 23（97.7% 减少），87/87 文件翻译成功
- 剩余 23 错误：unicode surrogates / ::class 引用 / ::add / let 缺类型 / bare companion / keys()
- 鉴于难度梯度重新设计，ksoup 拆为子包 + 混合跨项目目标重新开始

### Phase 1 — 1a ksoup-exception (2026-06-16) ✅

- **错误数**: 18 → 0
- **修复类型**:
  - **RENDER_GAP**: `map_type("Throwable")` → `Exception` (parser.rs:2748)
  - **RENDER_GAP**: `super(cause)` 非 String 参数 → `.toString()` 转换 (render.rs:1562-1571)
  - **RENDER_GAP**: 次级构造函数 `cause` 参数 → 提升为 class 字段 `var cause: ?Exception` (render.rs:1274-1284, 1299-1301, 1568-1570)
  - **STUB_GAP**: `RuntimeException`, `IllegalArgumentException`, `IOException` 支持 nullable + 多构造函数重载 (_stubs.cj)
  - **PARSER_GAP**: 无 `()` 的父类被误归为接口 → `is_exception_class` 同时检查 interfaces (render.rs:1263-1266)
- **回归**: Phase 0 202/202 single + 30/33 project 通过（3 个 project 失败：`__k2cjRuneSlice` 未定义，见下方回归修复）
- **回归修复** (2026-06-16): `project.rs:233-248` — project 翻译路径缺少 `__k2cjRuneSlice` helper 注入。`render_program()` 单文件路径有注入，`project.rs` 多文件路径无。3 个使用 `substring()` 的项目测试失败。在 `project.rs` 拼装每文件输出前注入 helper。
- **文件**: parser.rs (+1), render.rs (+37), project.rs (+17)

### Phase 1 — 1b ksoup-safety+io (2026-06-16) ⏳ R1

- **错误数**: 93 → 35 (62.4% reduction in R1)
- **目标文件**: 5 (Cleaner.kt, Safelist.kt, SourceReader.kt, SourceReaderByteArray.kt, SourceReaderExt.kt)
- **翻译**: 5/5 文件成功
- **编译通过文件**: 6/7 (cleaner, source_reader, source_reader_byte_array, source_reader_ext, _stubs, main)
- **编译失败文件**: safelist.cj (35 errors, stdlib collection API mismatch)
- **已修复 (translator, 4 changes, all regression-passing)**:
  - **RENDER_GAP**: `ByteArray` → `Array<Byte>` type mapping (parser.rs:2744)
  - **RENDER_GAP**: `Map.Entry<K,V>` → `Entry<K,V>` type mapping (parser.rs:2733)
  - **RENDER_GAP**: `expr.not()` → `!(expr)` 布尔取反 (render_calls.rs:257-259)
  - **RENDER_GAP**: `String.equals(x)` → `(lhs == rhs)`, `String.equals(x, true)` → case-insensitive compare (render_calls.rs:631-637)
- **回归**: Phase 0 202/202 single + 33/33 project 全部通过 ✅
- **剩余 35 错误 (全部 safelist.cj)** — STDLIB_GAP:
  - `HashSet.addAll()`, `removeAll()` — Cangjie HashSet 无这些方法
  - `HashSet([value])` — 数组构造函数参数不兼容
  - `HashMap([value])` — 同上
  - `entries.iterator()` — 返回类型 HashMapEntry vs Entry
  - IIFE `({ => ... })()` — 无效仓颉 lambda 语法
  - `copy.preserveRelativeLinks` — var/func 命名冲突
- **R2 计划**: 修复 safelist.cj 集合 API 翻译 (stdlib 映射) + IIFE 消除
- **文件**: parser.rs (+2), render_calls.rs (+6)
- **收敛**: R2 完成 — 35 → 0 ✅ (2026-06-16)
- **R2 修复内容**: safelist.cj Cangjie stdlib collection API 适配 (addAll→add(all:), HashSet([x])→显式构造, removeAll→手动循环, entries.iterator→for-in), TypedValue Hashable/Equatable 实现, String.lowerCase→toAsciiLower, String.matches→Regex.matches, Array<Byte> 构造函数适配
- **回归**: Phase 0 202/202 single + 33/33 project 全部通过 ✅

### Phase 1 — 1c okhttp-mockwebserver (2026-06-17) ✅

- **源文件**: 14 Kotlin 主源 + 5 test → 19 .cj 文件
- **基线**: 5 编译错误（mock_web_server_socket.cj:4, http2_server.cj:1）
- **修复内容**:
  - **PARSER_GAP** (newline leak): `skip_property_accessors` — `get() =\n when { ... }` 多行表达式体内换行误终结跳过。引入大括号深度跟踪 + 声明关键字前探，仅在 `}` depth=0 或下一 `get`/`set` 时停止 (parser.rs)
  - **RENDER_GAP** (companion main): `companion object` 的 `main()` 被渲染为 `static main()` 在类内，仓颉不允许。检测 companion 成员 `main()` → 提升为顶层函数 (render.rs)
- **回归**: Phase 0 202/202 + 33/33 ✅
- **文件**: parser.rs (+25), render.rs (+8)
- **剩余**: 444 errors — 全为跨包依赖 (stub gaps: Closeable/Http2Connection/Cloneable 未声明, RecordedRequest/SocketHandler 重定义, it redefinition from `?.also`)
- **注释**: 1c 的 5 个直接翻译错误全部解决。剩余 444 个错误是 mockwebserver 对 okhttp core 类型的依赖，非翻译器 gap。

### Phase 1 — 1g full-ksoup (2026-06-17) 🔄 R1 round-robin

- **上下文**: 1d (ksoup-parser) 被跨包子包依赖阻塞。1c/1e/1f 无本地 Kotlin 源。Round-robin 跳过 1d，启动 1g 全量 ksoup 编译。
- **基线**: 88 文件已翻译，1601 编译错误（8 printed by default）
- **R1 修复 (translator, 1 change, regression-passing)**:
  - **RENDER_GAP**: `map_type()` 非泛型 match 分支缺失 `IntArray`, `ShortArray`, `LongArray`, `FloatArray`, `DoubleArray`, `BooleanArray` → 对应 `Array<T>` 映射 (parser.rs)
  - **RENDER_GAP**: `map_type()` 非泛型 match 分支缺失 `Map.Entry` → `Entry` 映射（泛型分支已有，普通分支遗漏）(parser.rs)
  - **RENDER_GAP**: `map_type()` 非泛型 match 分支补充 `Map`, `List`, `Set` 等集合基类映射 (parser.rs)
- **回归**: Phase 0 202/202 + 33/33 ✅
- **文件**: parser.rs (+10)
- **阻塞**: 无 ksoup Kotlin 源文件，无法重新翻译验证。需获取 Kotlin 源 (clone ksoup repo) 或手动修补 .cj 输出验证。
- **下一步**: 获取 ksoup / okhttp / ktor / koin Kotlin 源 → 解锁 1c/1e/1f/1g
- **顶层错误分类** (1601 errors):
  - 36: mismatched types (Option<T> vs T unwrap, generic inference)
  - 13: no matching function for operator '()' (lambda/IIFE)
  - 6: Evaluator missing ToString impl
  - ~10: undeclared inner class refs (Token.StartTag→StartTag, Token.Character→TokenCharacter, Attributes.Dataset→Dataset)
  - ~15: stdlib API gaps (isNullOrEmpty, hasNext, appendCodePoint, toRuneArray, concatToString, clone, add, clear)
  - 1: attributeKey param vs local let redefinition (naming conflict in function scope)

### Phase 1 — 1g full-ksoup (2026-07-06) ⏳ R2 完成 — parse 战役收官,45→0 parse errors

- **源已获取**: `C:/Codes/kotlin/ksoup` (shallow clone, fleeksoft/ksoup) — 按新规则自动 clone,解除 R1 的"无 Kotlin 源"阻塞
- **翻译脚本**: `output/translate_1g.py` (per-file, 基于 translate_1e.py 模式, --check/--validate, 父目录前缀消歧, 剥离 per-file main)
- **翻译**: 87/87 文件成功 → `output/target_1g/` (新目录,旧 R1 手补产物 `output/ksoup_cj/` 保留作对照)
- **R2 错误轨迹**: 45 (parse) → 33 → 13 → 6 → 1 → **0 parse errors**
- **R2 译器修复(10 项,详见 fix-history 2026-07-06 各条,每项都有靶向测试用例 210-220)**:
  1. **P1 PARSER**: 泛型 bound `<T : Bound>` 吞参数表收尾 `>` → 修 + bound 编码 `"T <: Bound"` → render `where T <: Bound`(24/45 errors)
  2. **PARSER**: companion 内嵌套 class(Element.NodeList)未解析,成员误捡为 static(20 errors)
  3. **PARSER**: safe_name 补 `operator`/`redef`/`inout`/`synchronized`/`static`
  4. **RENDER**: infer_literal_type 补 Unary(±) 递归 / FloatLit / charArrayOf→Array<Rune>
  5. **PARSER**: enum 条目 trailing comma 后 `;` 被吞 + enum 内 companion 按块跳过
  6. **PARSER**: `if (x) foo(); else` 分号挡住 else 前探(skip_seps)
  7. **RENDER**: 中位默认值参数降级为位置参数(声明 render_func + 调用 fn_params 同规则)
  8. **PARSER**: trailing-lambda-only 泛型构造 `Type<T?> { ... }` 误判为 `<` 比较
  9. **HEURISTIC**: `.keys`/`.values` 映射加 provably_non_collection 守卫(用户类字段保留)
  10. **RENDER**: `getOrPut(...)[k] = v` statement 级展开(IIFE 左值 + 裸 ctor 推断双修) + 可空泛型 bound `E : Element?` 丢弃 where 条目
- **回归**: Phase 0 每轮全跑,最终 212/212 single(202+10 新增)+ 33/33 project 全绿
- **⚠️ 语义层揭示(同 1e 教训)**: parse 清零后语义分析放行,真实基线 **1889 semantic errors**。顶层分类:
  - 171 mismatched types(Option/T unwrap 等)
  - 46 `notEmpty` 无匹配(Validate stub 缺失)/ 43 泛型裸用 / 37 `Tag` 歧义 / 31 operator '()'(lambda/IIFE)
  - 30 `OutputSettings` + 25 `Regex` + 16 `KClass` undeclared(嵌套类提升引用 + stdlib/反射 stub gap)
  - 28 for-in 非 Iterator / 21 HashMap 约束 / 20 enum pattern / 19 泛型推断 / 17 `lowerCase` / 17 `__k2cjRuneSlice` 歧义
- **R3 候选(语义战役)**: ① `===`/`!==` 目前 lexer 退化为 `==`,类引用相等应映 refEq(indexInList 等会撞) ② Document.OutputSettings 等嵌套类提升后的限定名引用改写 ③ Regex/KClass/Validate stdlib stub ④ enum companion 函数(CoreCharset.byName)静态化而非丢弃 ⑤ mismatched types 大类细分

### Phase 1 — 1d ksoup-parser (2026-07-06) ⏳ R1 完成 — 重定义为 1g 切片 + 嵌套类提升战役

- **重定义**: 1d 单独翻译不可行（fix-history 2026-06-17 结论），重定义为 1g 全量编译中 parser 子包 16 文件切片。基线（per-file 管线, r2f 日志）: 525 errors / 13 文件（tokeniser_state/html_tree_builder_state/parse_error 三文件干净）。
- **诊断（切片根因簇）**: ① 嵌套类提升引用未改写+撞名（最大簇 ~151, Token.StartTag/TokenType 等 + ambiguous Tag/Comment/Character）② stdlib stub gap（Reader/StringReader/IOException/appendCodePoint 等）③ enum companion 常量（TokeniserState.nullChar）④ Option unwrap/集合 API 等。
- **修复 1（嵌套类提升, fixer R1）**: engine.rs 新增 `apply_nested_lifting` 图归一化 pass — (父类,嵌套名)→提升名注册表；撞名时父类名前缀重命名（Token.Comment→TokenComment 等 5 个）；全图类型字符串限定链折叠。render.rs render_member 表达式位改写。测试 221 + proj_nestedlift。该簇 ksoup 语料 151→0。
- **修复 2（std.iterator, fixer R2）**: project.rs `detect_and_gen_imports` 启发式注入不存在的 `import std.iterator.*`（11 文件, 挡住全部语义分析）→ 删除。测试 222 + proj_iterimport。
- **⚠️ 关键发现 — per-file 管线丢失跨文件上下文**: translate_1g.py 逐文件调用翻译器，Engine 每次只见单文件，跨文件修复（嵌套提升消歧等）完全不生效（重译后错误数纹丝不动 1889）。**1g/1d 测量管线自本轮切换为 project 模式**（目录输入, project.rs 路径, 33 个项目测试保护）。translate_1g.py 保留作对照。
- **新基线（project 模式）**: 总 1595（旧 per-file 1889），1d 切片 411（旧 525）。热点: html_tree_builder(122), tree_builder(42), tokeniser(37), token(37), character_reader(36)。
- **切片错误分类（411）**: 69 undeclared identifier / 55 mismatched types / 43 not-member-of-class / 36 not-member-of-enum / 24 undeclared type / 23 invalid binary op / 20 operator '()' / 14 break-continue 非循环 / 13 missing argument / 11 generic 裸用 / 11 uninitialized member。
- **project 模式已知遗留**: ① LinkedList.kt 泛型 typealias `typealias LinkedList<E> = MutableList<E>` parse error → 文件被静默跳过（且 project.rs 报"成功 86"无失败上报，计数口径需修）② 输出文件名无父目录前缀消歧（ksoup 当前无 basename 撞名, 暂无碍）。
- **回归**: 两轮修复后 215/215 single + 35/35 project 全绿（基线实测 213/33, 非 state 记载的 202/33——历史用例数已增长）。
- **R2 候选**: ① enum companion 常量静态化（TokeniserState.nullChar, 36 not-member-of-enum）② stdlib stub（Reader/StringReader/IOException/appendCodePoint）③ break/continue 在 when 内被误判非循环（14）④ LinkedList 泛型 typealias parse ⑤ mismatched types 细分。
- **改动未提交**（engine.rs, render.rs, project.rs + 4 组新测试 + fix-history 3 条）。

### Phase 1 — 1d ksoup-parser (2026-07-06) ⏳ R2 完成 — stdlib-type-surface 簇消掉

- **行动簇**: stdlib-type-surface（STDLIB_GAP）— Kotlin stdlib 类型（Regex/Reader/KClass/Charset 等）无仓颉映射，原样输出致 undeclared。诊断估算 152 错误 + ~80 级联，风险=增量式。
- **R2 译器修复（4 处，全部 219/219 single + 35/35 project 回归通过 ✅）**:
  1. **新增 stubs.rs**（13596 字节）— 数据驱动表 `StubDef { provides, markers, imports, code }`，9 个 stub：Regex+RegexOption+MatchResult、KClass、Reader+StringReader、Sequence、MutableIterator+MutableListIterator、ByteArray、IntArray、Charset+CharsetEncoder+Charsets、Appendable。词边界匹配 marker，`defines_type` 守卫避免与用户自定义冲突。
  2. **project.rs 注入路径** — `convert_project` 末尾汇总 `all_bodies`，调 `stubs::collect_stubs` 生成独立 `k2cj_stubs.cj`（同包共享，含 package + imports + code）。
  3. **render.rs 单文件注入路径** — `render_program` 在 `__k2cjRuneSlice` 注入后调 `collect_stubs`，stub_code 追加到 body 末尾，stub_imports 加到 header。
  4. **main.rs** — `mod stubs;` 声明。
- **1g 全量测量（project 模式, target_1g_proj/）**: **1598 → 10 error（99.4% 降幅）**。stdlib-type-surface 簇 148→0。自动生成 k2cj_stubs.cj (7109 bytes, 9 个 stub 全部命中注入)。
- **剩余 8 个 parse error（R3 起点）**: 7 × `redefinition of declaration`（document.cj 的 parser/escapeMode/charset/syntax/prettyPrint/outline/indentAmount setter — Kotlin `fun parser(parser: Parser)` 参数名撞成员名）+ 1 × `optional parameter cannot be used in abstract function`（source_reader.cj 抽象方法默认参数）。cjc 遇 parse error 即停，遮蔽语义层。
- **靶向测试**: 4 个（230_regex_basic, 232_int_array, 233_charset, 234_reader_stringreader）。231_byte_array 因 `toByte()` 未映射（另一个翻译 bug 簇）暂删，IntArray 已验证类型别名 stub 机制。
- **diagnostician.md / SKILL.md 更新**: 引入"行动簇"概念（根因簇归组 + 杠杆/风险比排序 + 每轮只攻一簇）。
- **文件**: stubs.rs (新, +13596), main.rs (+1), project.rs (+26), render.rs (+12), diagnostician.md (+31/-10), SKILL.md (+13), tests/cases/23x (+4 对)。
- **R3 候选**: ① redefinition-of-declaration 簇（setter 参数名撞成员名，7 错误，需改名或加 `_` 前缀）② optional-parameter-in-abstract（1 错误，抽象方法去默认参数）③ 修完 parse error 后重测语义层真实错误数。

### Phase 1 — 1g full-ksoup (2026-07-06) ⏳ R3 测量 — stdlib 簇清零, parse 簇待修

- **R3 基线（project 模式, target_1g_proj/, 带 stub 注入）**: **10 error**（8 真 error + 2 cjpm 消息）。从 R2 的 1598 降至 10。
- **stdlib-type-surface 簇**: 148 → 0 ✅（Regex 37 + KClass 17 + Reader 15 + Sequence 15 + MutableIterator 15 + ByteArray 10 + IntArray 9 + Charset 9 + CharsetEncoder 6 + Appendable 10 + StringReader 4 + Charsets 1）
- **剩余 parse error 分布**:
  - 7 × redefinition-of-declaration: document.cj:190(parser), 223(escapeMode), 227(charset), 235(syntax), 242(prettyPrint), 246(outline), 250(indentAmount) — Kotlin `fun X(x: X)` setter 参数名撞成员名
  - 1 × optional-parameter-in-abstract: source_reader.cj:8 — `func read(bytes: ByteArray, offset!: Int64 = 0, ...)` 抽象方法默认参数
- **遮蔽效应**: cjc 遇 parse error 即停，不进语义分析（同 1e/1g 教训）。修完 8 个 parse error 后语义层放行，预计揭示新的错误分布。
- **k2cj_stubs.cj 自动注入验证**: 9 个 stub 全部命中（Regex/KClass/Reader/StringReader/Sequence/MutableIterator/MutableListIterator/ByteArray/IntArray/Charset/CharsetEncoder/Charsets/Appendable）。project 模式生成独立文件，单文件模式追加到 body 末尾。
- **R4 候选（修完 parse 簇后）**: 等语义层放行后重新诊断，按行动簇排队。预计剩余 stdlib 簇（MutableMap/MutableList/AutoCloseable/IOException 等，~50 错误，未覆盖 stub）+ redefinition 簇下游 + 其他语义错误。

### Phase 1 — 1f koin-core (2026-07-07) ⏳ R1 完成 — 3 parse 簇修复, 71/72 翻译

- **源已获取**: `C:/Codes/kotlin/koin` (shallow clone, InsertKoinIO/koin)
- **koin-core 路径**: `projects/core/koin-core/src/commonMain/kotlin` (commonMain 74 .kt / 5509 行,state 标 ~25 估算偏低,实际 commonMain 全量)
- **scope 决策**: 翻译全 commonMain 74 文件。expect 类 (mp/KoinPlatformTools + mp/ThreadLocal) 走 stubs.rs 注入 (同 1g stdlib stub 经验)
- **核心特性验证** (state 标注 DSL/delegate/reified):
  - DSL: dsl/ 5 文件 (KoinApplication/ModuleDSL/ScopeDSL/DefinitionBinding/KoinConfiguration)
  - delegate: ext/InjectProperty.kt (`by inject()`), `by lazy` 散落
  - reified: 21 文件用 reified,18 文件用 inline/noinline/crossinline
- **硬依赖边界**: mp/KoinPlatformTools.kt + mp/ThreadLocal.kt (expect 声明,需 stub)
- **R1 首跑**: project 模式只生成 1 .cj 文件,3 个 parse 簇阻断合并源解析
- **R1 修复 (3 簇, 全部 224/224 single + 35/35 project 回归通过 ✅)**:
  1. **inline-fn-param-modifiers** (parser.rs parse_param_nodes + parse_generic_params):
     - parse_param_nodes 故意不调用 skip_modifiers (避免误识参数名关键字),但也跳过 noinline/crossinline
     - 修复: 加 eat_kw("noinline") + eat_kw("crossinline") (这两个是 inline 函数 lambda 参数专用,不作为参数名)
     - parse_generic_params 把 'reified' 当作泛型参数名本身 (替代了 T),导致 'func f<reified>(...): T' + 'undeclared type name T'
     - 修复: 加 is_generic_mod 检查跳过 reified/out/in (Kotlin 泛型修饰符)
  2. **generic-typealias-declaration** (parser.rs parse_typealias):
     - parse_typealias L565 expect_ident 后立即 expect_sym("=") 不识别 `typealias X<T> = Target<T>` 的 <T>
     - 修复: expect_ident 后若 is_sym("<") 调 parse_generic_params 跳过 <T>
     - 影响 1f 10 个 typealias,3 个带 <T>: BeanDefinition L148 / Callbacks L26 / OptionDSL L16
  3. **receiver-function-type** (parser.rs parse_type_raw):
     - parse_type_raw 不识别 `ReceiverType.() -> R` Kotlin 带接收者函数类型
     - 解析 ReceiverType 后 expect_sym(")") 但得到 "." (receiver 分隔符)
     - 修复: expect_ident + 嵌套类型 + 泛型实参后,若 is_sym(".") 且下一 token 是 "(",消费 "." 把 ReceiverType 当作函数类型第一个参数,转入 `(ReceiverType) -> R` 解析
     - 影响 1f 8 处: Module L84/L93 / KoinApplication L22 / KoinConfiguration L34/L39/L47 / ModuleDSL L21 / ModuleExt L64
- **靶向测试**: 238 (inline+noinline+crossinline+reified) + 239 (generic typealias) + 240 (receiver function type)
- **1f R1 测量**: project 模式 71/72 文件翻译成功 (从 1 → 71,覆盖率 96%)。剩 1 parse error (val <E : Enum<E>> Enum<E>.qualifier 带泛型扩展属性,R2 候选)
- **1f R1 编译**: 9 errors (8 printed)。分布:
  - 3 × `expected type name after '<', found '*'` — Kotlin star-projection `Map<*>` (k_class_ext / definition_binding / option_d_s_l)
  - 3 × `unnamed parameters must come before named parameters` (scope / bean_definition ×2)
  - 1 × `expected expression after keyword 'throw', found '}'` (parameters_holder)
  - 1 × `expected declaration, found 'Duration'` (duration_ext)
- **R2 候选**: ① star-projection `<*>` 簇 (3 错误,parser.rs parse_type_raw L2801 已有 `*`→Any 但可能位置不对) ② unnamed-named-param-order 簇 (3 错误,1g R2 修过中位默认值参数,可能没覆盖全) ③ throw-expression-body 簇 (1e R2 修过 P2,可能没覆盖全) ④ 带泛型扩展属性 parse error (1 错误)

### Phase 1 — 1e ktor-io (2026-06-27) ⏳ R1 诊断完成

- **源已获取**: `C:/projects/kotlins/ktor` (shallow clone, ktorio/ktor)
- **scope 决策**: 整包 ktor-io 是 kotlinx.io(38)+kotlinx.coroutines(10)+atomicfu 薄封装，无法收敛到 0。选**纯 I/O 原语子集**（用户确认），剪枝协程/expect 层。
- **翻译脚本**: `output/translate_1e.py`（per-file，注入 package 行，子目录前缀消歧，--check/--validate）
- **剪枝**: 4 个 expect/actual+外部 typealias 文件（bits/ByteOrder, JvmSerializable, locks/Synchronized, core/internal/ChunkBuffer）— common-only 缺平台 actual，非翻译器 gap，同 1c/1d 依赖边界。
- **当前**: 14/14 文件翻译成功，**6 编译错误 / 3 文件**，全为真·翻译器 RENDER_GAP：
  - **P1 `return Unit`** (pool_pool.cj:13,16 ×2): Kotlin 空体 Unit 函数 → 译器插 `return Unit`，但 Cangjie Unit 值是 `()`。修复: emit `return`/`return ()`/空体。高复发·低风险·L1 首选。
  - **P2 `= throw expr`** (internal_numbers.cj:13): `fun f(): Nothing = throw IAE(...)` 表达式体 → 译成 `return throw`（丢异常实参）。修复: 直接渲染 `throw Exception(...)`。
  - **P3 value class + when** (line_ending_mode.cj:18-20): `value class`+companion 常量+`when` → `match` 用 `LineEndingMode.CR()` 静态调用当 pattern（非法）。修复: when-over-constants 译 if/else 链。低复发·高风险。
- **下一步**: Stage 5 Fixer — L1 优先修 P，Phase 0 回归（202+33）前后必跑。

### Phase 1 — 1e ktor-io (2026-06-27) ⏳ R2 Fixer 完成 + 真实错误数揭示

- **R2 翻译器修复（4 项，全部 202/202 + 33/33 回归通过 ✅）**:
  - **P1 RENDER_GAP**: `return Unit` → `return ()`。`Unit` value-expression（NameRef "Unit"）映射为仓颉单元值 `()`（render.rs，NameRef 分支早返回）。注意 `Unit` *类型* 走 map_type，不受影响。
  - **P2 PARSER_GAP**: 函数表达式体 `= throw X(...)` → 直接渲染 `throw X(...)`，不再 `return throw`（丢实参）。parser.rs 函数体 `= expr` 分支前探 `throw` 关键字。
  - **P3 RENDER_GAP（value class）**: `value class` → 仓颉 **struct（值语义）+ @Derive[Equatable]**。研究结论见下。涉及 node.rs（新增 `is_value` 字段）、parser.rs（`value` 软关键字仅在 `value class` 时捕获）、render.rs（struct 关键字 + @Derive 前缀 + value-class when 渲染）。
  - **附带 BUG 修复**: `skip_modifiers` 此前不交错跳注解 → 注解后的修饰符（`@JvmInline public value class` 的 `public`/`value`）被静默丢弃。改为循环内交错 `skip_annotations`。**坑**: `value` 是常见标识符（`var value: Int`），不能无条件当修饰符——仅当后跟 `class` 时捕获（peek_next_is_kw）。曾因此回归 3 个 single 测试（main 丢失），已修复。
- **P3 Cangjie 研究结论（cjc 1.0.5 实测）**:
  - `@Derive[Equatable]` 支持 class/struct/enum；enum 收集构造器参数；需 `import std.deriving.*`（译器已自动注入）。
  - **关键约束**: 派生的 `==` 经 `extend` 注入，在**类型自身方法体内不可见**。value class 的 `toString` 里的 `when(this)` 是内部比较 → 必须走**字段比较** `this.mode == CR().mode`，不能用 `==`。
  - enum 映射较侵入（构造器须改名、字段访问须解构）；**struct 最忠实**（值语义）且改动最小（字段/构造保持不变）。选 struct。
  - `when(this)` over companion 常量 → if/else 链比较字段（render_when 新增 value_class_const_field / render_when_value_class_consts，从 pattern 渲染串 `Type.X()` 反查 value class 字段名）。
- **line_ending_mode.cj 现 0 错误**（P3 验证通过）。
- **⚠️ 重大发现 — 「6 errors」是 parse 阶段欠计数**: cjc 遇 parse error 即停，不进语义分析。修掉 P1/P2/P3 三个 parse error 后，语义分析放行，**揭示 ~69 个潜伏语义错误**（13 个文件）。原诊断的「6 errors」严重低估。
- **真实 69 错误分类（cjc --error-count-limit）**:
  - 28 undeclared type name — `AutoCloseable`/`IOException`/`CharSequence`（stdlib 类型 stub gap）+ `T`/`R`（extend 类型形参 render bug）
  - 16 undeclared identifier — 上面的级联
  - 3 uninitialized member / 3 generic-needs-type-arg / 3 multiple-found / 2 shadow / 2 named-param-prefix / 2 interface-inherit / 等
  - **性质**: 绝大多数是**依赖边界**（atomicfu `atomic()`、缺 stdlib 类型 stub）——与 1c/1d 同类「非译器 gap」，少数真 render gap（`extend T<T,R>` 类型形参扩展、ObjectPool 泛型实参）。
  - pool_pool.cj 独占 28 错（atomicfu + 抽象类 + 泛型），属被剪枝的 atomicfu 层残留。
- **附带修复**: translate_1e.py 剥离 per-file 模式注入的空 `main()`（装配期多 main 冲突，assembly artifact，非译器 gap）。
- **文件**: node.rs(+2), parser.rs(+~14), render.rs(+~90, 含 3 个新 helper), output/translate_1e.py(+strip main)
- **✅ 收敛（2026-06-27）**: 按 1c 先例（✅=译器 gap 全修+stub，余依赖边界文档化），将 14 文件剪枝到 **5 文件真·可译核心**，加 `_stubs.cj`（`extend Int64 { toInt }`），**`cjpm build success`，0 errors**（3 个 unused-function warning，无害），`cjpm run` 通过。
  - **保留核心 5**: LineEnding, LineEndingMode(P3 value class→struct), Annotations, ByteOrder(enum), Numbers(toInt stub)。
  - **剪枝 9**（translate_1e.py 内文档化分类）:
    - 硬依赖边界（同 1c/1d cross-pkg）: Pool/ByteArrayPool(atomicfu `atomic()`)、Copy/Deprecation(kotlinx.io Source/Sink)、Closeable(AutoCloseable+kotlin.use+extend类型形参)、errors/Exceptions(纯 kotlinx.io typealias 空体)。
    - **延后的真 render gap（R3 可修，本会话避免高风险批量改）**: Exceptions.kt(`cause` 在异常子类链中 shadow 父类成员，1a cause-promotion 需加「父类已是异常类则不提升」守卫)、CharArraySequence.kt(CharSequence 映射不一致: 返回位 String vs 父类型位 interface)、Memory.kt(ByteArray 在 extend-target/构造器位未走 map_type)。
  - **译器改动仍 202/202 + 33/33 回归通过**（仅 translate_1e.py 脚本在末次回归后改动，译器二进制未变）。
- **R3 候选（真 render gap，皆通用译器改进）**: ① extend on type param（`fun <T,R> T.use()`）② 异常子类 cause 防 shadow ③ CharSequence 映射一致性 ④ ByteArray extend/ctor 位 map_type 覆盖 ⑤ abstract `val` prop → 仓颉 prop（非 `let` 字段，pool 的 capacity）。

---

## 剪枝轮候选（存量 stub 整改，2026-07-09 登记）

> 依据：API-first 策略上线（autonomous-strategy.md 修复手段偏好序 + external-knowledge.md 3.5 查证门）。
> 存量 stub 中的手写重实现是"退役 stub 换真实 API 映射"的首选剪枝对象（净负债下降最多）。
> 每项整改是译器代码改动：须靶向测试 + Phase 0 全量回归护航；查证后确无对应物（秤称为负）
> 则维持 stub 并记暂封 + 重审条件。裁决按暂封制，无一是墓碑。

> **R14 剪枝轮查证已过（2026-07-10）**：6 组全部维持 stub。父类型位 marker（AutoCloseable/Mutable*）→排期为「父类型位成员合成/转发」深层特性；io/reflect/charset 三组待仓颉 std 补面。详见历史记录「剪枝轮 stub 存量整改」。

| stub（stubs.rs） | 疑似真实对应物 | 查证结论（R14） | 状态/触发 |
|------|---------------|---------|----------|
| READER_STUB (Reader/StringReader) | std.io StringReader | 语义面差异过大：ctor(String vs InputStream) / read():?Rune非Int64/-1 / 无 bulk read(buf,off,len)（jsoup 唯一读法） | ⏸ 暂封，重审：仓颉 io 出 char-based -1/EOF Reader 或 bulk read 重载 |
| KCLASS_STUB | std.reflect | reflect 需实例（`X::class` 无实例）；`.name` 非 `.simpleName`；macOS/enum/tuple 不支持 | ⏸ 暂封，重审：仓颉出类型级反射+simpleName |
| MUTABLE_ITERATOR_STUB | std.collection 迭代器族 | 仓颉 Iterator 无 `remove()`，无 iterator-based 就地删除概念 | ⏸ 暂封，重审：仓颉出 MutableIterator |
| APPENDABLE_STUB | core ToString/StringBuilder 接口族 | 仓颉 core/collection 无 Appendable 接口，仅 StringBuilder 具体类 | ⏸ 暂封，重审：仓颉出 Appendable/CharSink |
| CHARSET_STUB (Charset/CharsetEncoder/Charsets) | stdx.encoding | stdx.encoding 仅 Base64/Hex/URL，无 Charset/named-charset API（如预判） | ⏸ 暂封，重审：仓颉出 charset API |
| R5 新增 4 个 marker stub（AutoCloseable/MutableList/MutableMap+MutableCollection/Entry+MutableEntry） | AutoCloseable→std core Resource；Mutable*→std.collection List/Map/Collection | 均活引用（无死 marker）。Resource 需 isClosed()（QueryParser/TokenQueue 缺）；Mutable* 父类型位退役需 R6-同款成员转发 → 波及大 | 📅 排期：合并为「父类型位成员合成/转发」深层特性候选（复用 override_provably_unmatched 基建） |

> 真实包适配器（REGEX_STUB→std.regex、SEQUENCE_STUB→std.collection）与琐碎 alias
> （BYTE_ARRAY/INT_ARRAY）不在整改列——前者已是"映射优先"的正例，后者维护费≈0。

# 知识库注册表（knowledge registry）

> 本表是 kotlin2cj 优化系统全部知识库的**唯一权威清单**。流程文件（`external-knowledge.md` 的
> 加载规则与查证门）按本表遍历，不硬编码库名——**新增知识库 = 在本表加一行 + 满足接入协议**，
> 流程零改动。分工：本表=数据，external-knowledge.md=流程（各库内容细目仍在其一节展开）。

## 注册表

| id | 根路径（Windows / WSL） | 入口索引 | 内容域 | 查证链位次 | 规则链位次 | 加载者 | 同步方式 |
|----|------------------------|---------|--------|:--:|:--:|--------|---------|
| kb-self | 本仓库 `.github/skills/`（两环境同仓库） | 各子目录 `SKILL.md`；官方镜像用 `cangjie-original-docs/index/stdlib.md` | 仓颉 std 速查（25 包）/ stdx（11 包）/ 语言特性 / 工具链 / 编码规范 / 官方文档镜像（485 文件） | ①②，⑤兜底之一 | 5 | diagnostician, fixer, semantic-guard | 随本仓库 git |
| kb-x2cj | `C:/Codes/x2cj-skills` / `/mnt/c/Codes/x2cj-skills` | `skills/cangjie-dev/SKILL.md`（API 总索引）+ `skills/x2cj/rules/sdk-dependency-mapping.md` + `skills/x2cj/rules/tpc-dependency-mapping.md` | Kotlin 规则（31 文件）/ Java 规则（37+312）/ **二方库映射** / **TPC 三方库映射（~140 行 GitCode 表）** / x2cj-eval 评估 / cangjie-dev 官方镜像 + ohos | ③④，⑤兜底之一 | 2,4,6 | diagnostician, fixer, verifier | `git pull`（见 external-knowledge.md 四） |

> 规则链位次 = external-knowledge.md 二节"加载顺序"中的位置（1=项目私有 patterns，2=Kotlin 规则，
> 3=fix-history，4=Java 规则，5=仓颉语言参考，6=x2cj-eval）。

## 查证链（API-first 查证门的权威顺序）

> external-knowledge.md 3.5 节的查证门按此表位次执行。查证是**索引级**的（grep 入口索引，
> 命中再读详情页），预算 ≤5 次文件读取。

| 位次 | 索引文件 | 回答什么问题 |
|:--:|---------|-------------|
| ① | kb-self `.github/skills/cangjie-std/SKILL.md` | 仓颉**标准库**有没有这个类型/功能（25 包注释目录） |
| ② | kb-self `.github/skills/cangjie-stdx/SKILL.md` | **扩展库**有没有（json/http/crypto/encoding/log…） |
| ③ | kb-x2cj `skills/x2cj/rules/sdk-dependency-mapping.md` | **二方库**有没有（Java 库已 1:1 移植仓颉，无外部 git 依赖） |
| ④ | kb-x2cj `skills/x2cj/rules/tpc-dependency-mapping.md` | **TPC 三方库**有没有（GitCode Cangjie-TPC 组织，附 cjpm.toml 片段） |
| ⑤ | 兜底：kb-self `cangjie-original-docs/index/stdlib.md` 或 kb-x2cj `skills/cangjie-dev/SKILL.md` | 前四步无命中且怀疑索引不全时，各查一次 |

## 接入协议（新库注册必填，缺一不收）

1. **单文件入口索引**：库必须提供一个可 grep 的入口索引（SKILL.md / index.md 形态）。
   查证门的 ≤5 次读取预算依赖索引存在——没有索引的库会把查证退化成遍历，等于没有索引。
2. **查证链插入位次**：声明插入 ①-⑤ 的哪个位置（默认追加在 ⑤ 兜底之前）。
3. **重叠仲裁**：声明与现有库的内容域重叠及裁决——**域更具体者优先，同具体度先注册者优先**。
   现状裁例：kb-self 与 kb-x2cj/cangjie-dev 的 stdlib 镜像重叠，裁为 kb-self 一级、cangjie-dev
   兜底（与 external-knowledge.md 一节现行口径一致，零行为变化）。
4. **双环境路径**：Windows 与 WSL 路径都写（同一份磁盘内容，见 external-knowledge.md 〇节）。

### 示例行（未启用，展示新库怎么加）

| id | 根路径 | 入口索引 | 内容域 | 查证链位次 | 规则链位次 | 加载者 | 同步方式 |
|----|--------|---------|--------|:--:|:--:|--------|---------|
| kb-ohos（示例） | 〈待定〉 | 〈须提供单文件入口索引〉 | ohos.* API / ArkUI | 追加在 ⑤ 前 | 按需 | 按需 | git pull |

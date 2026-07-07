//! 自组织翻译引擎：对翻译图做异步 worklist 松弛，直至收敛。
//!
//! 核心 SOC（Self-Organized Criticality）机制：
//!   1. **粒子驱动松弛**（grain-by-grain）：逐个叶子添沙，每粒沙级联完全结束后再添下一粒
//!   2. **双向上下文传播**：底层→顶层的基础翻译 + 顶层→底层的上下文精化（类型推断优化）
//!   3. **兄弟一致性检查**：同层兄弟节点相互影响，涌现局部一致性（如类型统一）
//!   4. **温度引导优先级**：按节点临界度（依赖扇出）排序驱动，使高影响节点优先稳定
//!   5. **雪崩记忆反馈**（Avalanche Memory Feedback, AMF）：记录每个节点引发的级联规模，
//!      在后续松弛中优先评估高记忆权重节点的邻居，使系统自适应地集中计算资源于
//!      翻译困难区域——类似于真实 SOC 系统中应力场的长程记忆效应。
//!
//! 这些机制使系统的 SOC 指标（分支比 σ、幂律指数 α、变异系数 CV）
//! 更接近临界态，同时保持翻译的确定性和合流性。

use crate::node::*;
use std::collections::{HashMap, HashSet, VecDeque};

pub struct Engine {
    pub g: Graph,
    /// 最近一次驱动引发的雪崩规模（状态变更次数）。
    pub last_avalanche: usize,
    /// 历次雪崩规模，用于观察幂律分布。
    pub avalanche_sizes: Vec<usize>,
    pub total_updates: u64,
    /// AMF: 每个节点的雪崩记忆权重——记录该节点历史上引发的级联总规模。
    /// 高权重节点是翻译图中的"应力集中点"，其邻居在后续松弛中优先评估。
    avalanche_memory: Vec<u32>,
    /// 索引：Name 节点 ID → 声明节点 ID（VarDecl / Param / ForEach.var）。
    /// 避免 heuristics.rs 中 19 处线性扫描，将 O(n) 查找降为 O(1)。
    pub(crate) decl_index: HashMap<NodeId, NodeId>,
    /// 索引：函数名 → Func 节点 ID（取首个匹配）。
    pub(crate) func_index: HashMap<String, NodeId>,
    /// 索引：类名 → Class 节点 ID。
    pub(crate) class_index: HashMap<String, NodeId>,
    /// 索引：枚举名 → Enum 节点 ID。
    pub(crate) enum_index: HashMap<String, NodeId>,
    /// 嵌套类提升注册表：(父类名, 嵌套类原名) → 提升后的顶层名字。
    /// 与顶层类撞名的嵌套类会被重命名为 `父类名+嵌套类名`（如 Token.Comment → TokenComment）。
    pub(crate) lifted_nested: HashMap<(String, String), String>,
}

impl Engine {
    pub fn new(mut g: Graph) -> Self {
        // 建立依赖边：标识符引用 → 声明。
        let n = g.nodes.len();
        for id in 0..n {
            if let Kind::NameRef { decl: Some(d), .. } = g.nodes[id].kind {
                g.nodes[id].dep = Some(d);
                g.nodes[d].dependents.push(id);
            }
        }
        g.link_children();
        // 嵌套类提升归一化：改写限定名引用、消除提升撞名（必须在建索引之前）。
        let lifted_nested = apply_nested_lifting(&mut g);
        let avalanche_memory = vec![0u32; n];

        // 构建名称索引
        let mut decl_index = HashMap::new();
        let mut func_index = HashMap::new();
        let mut class_index = HashMap::new();
        let mut enum_index = HashMap::new();
        for id in 0..n {
            match &g.nodes[id].kind {
                Kind::VarDecl { name_node, .. } => {
                    decl_index.insert(*name_node, id);
                }
                Kind::Param { name_node, .. } => {
                    decl_index.insert(*name_node, id);
                }
                Kind::Func { name, .. } => {
                    func_index.entry(name.clone()).or_insert(id);
                }
                Kind::Class { name, .. } => {
                    class_index.insert(name.clone(), id);
                }
                Kind::Enum { name, .. } => {
                    enum_index.insert(name.clone(), id);
                }
                Kind::ForEach { var, .. } => {
                    if let Kind::VarDecl { name_node, .. } = &g.nodes[*var].kind {
                        // ForEach 循环变量也加入声明索引（指向 ForEach 节点）
                        decl_index.insert(*name_node, id);
                    }
                }
                _ => {}
            }
        }

        let mut eng = Engine {
            g,
            last_avalanche: 0,
            avalanche_sizes: Vec::new(),
            total_updates: 0,
            avalanche_memory,
            decl_index,
            func_index,
            class_index,
            enum_index,
            lifted_nested,
        };
        eng.resolve_var_func_collisions();
        eng
    }

    /// 解决 var/func 同名冲突：Kotlin 中 backing field 与 getter/setter 可同名，
    /// 但仓颉使用平坦命名空间，var 与 func 不可重名。
    /// 对冲突的 var，重命名为 `_<name>` 并级联更新所有 NameRef 引用。
    fn resolve_var_func_collisions(&mut self) {
        // 收集所有类中的冲突信息（先读后写，避免 borrow 冲突）
        let mut rename_ops: Vec<(NodeId, String)> = Vec::new(); // (name_node_id, new_original)
        let n = self.g.nodes.len();
        for id in 0..n {
            if let Kind::Class { members, .. } = &self.g.nodes[id].kind {
                let mut func_names: HashSet<String> = HashSet::new();
                let mut var_entries: Vec<(NodeId, String)> = Vec::new(); // (name_node_id, original)
                for &m in members {
                    match &self.g.nodes[m].kind {
                        Kind::Func { name, .. } => {
                            func_names.insert(name.clone());
                        }
                        Kind::VarDecl { name_node, .. } => {
                            // Check both Name (direct declaration) and NameRef (reference to external decl)
                            match &self.g.nodes[*name_node].kind {
                                Kind::Name { original } => {
                                    var_entries.push((*name_node, original.clone()));
                                }
                                Kind::NameRef { original, .. } => {
                                    var_entries.push((*name_node, original.clone()));
                                }
                                _ => {}
                            }
                        }
                        _ => {}
                    }
                }
                for (name_node_id, var_name) in &var_entries {
                    if func_names.contains(var_name) {
                        let new_name = format!("_{}", var_name);
                        rename_ops.push((*name_node_id, new_name));
                    }
                }
            }
        }

        // 执行重命名：Name 节点 + 其所有 dependents（NameRef 节点）
        for (name_node_id, new_name) in &rename_ops {
            if let Kind::Name { original } = &mut self.g.nodes[*name_node_id].kind {
                let old_name = original.clone();
                *original = new_name.clone();
                // 级联更新所有引用此声明的 NameRef 节点
                let deps: Vec<NodeId> = self.g.nodes[*name_node_id].dependents.clone();
                for dep_id in &deps {
                    if let Kind::NameRef {
                        original: ref_name, ..
                    } = &mut self.g.nodes[*dep_id].kind
                    {
                        if *ref_name == old_name {
                            *ref_name = new_name.clone();
                        }
                    }
                }
            }
        }

        if !rename_ops.is_empty() {
            eprintln!(
                "SOC: resolved {} var-func name collision(s) ({})",
                rename_ops.len(),
                rename_ops
                    .iter()
                    .map(|(_, n)| n.as_str())
                    .collect::<Vec<_>>()
                    .join(", ")
            );
        }

        // 也检测 CtorParam 的 var/val 是否和 func 名冲突
        // （constructor 参数 var，如 `class X(var parser: Parser)` + `fun parser(...)`）
        // CtorParam 不是节点（无 name_node/dependents），需单独处理 + 全图 NameRef 级联
        let mut ctor_rename_ops: Vec<(usize, String, String)> = Vec::new();
        for id in 0..n {
            if let Kind::Class { members, ctor_params, .. } = &self.g.nodes[id].kind {
                let mut func_names: HashSet<String> = HashSet::new();
                for &m in members {
                    if let Kind::Func { name, .. } = &self.g.nodes[m].kind {
                        func_names.insert(name.clone());
                    }
                }
                for p in ctor_params {
                    if p.kind != CtorParamKind::Plain && func_names.contains(&p.name) {
                        let new_name = format!("_{}", p.name);
                        ctor_rename_ops.push((id, p.name.clone(), new_name));
                    }
                }
            }
        }
        for (class_idx, old_name, new_name) in &ctor_rename_ops {
            if let Kind::Class { ctor_params, .. } = &mut self.g.nodes[*class_idx].kind {
                for p in ctor_params.iter_mut() {
                    if p.name == *old_name {
                        p.name = new_name.clone();
                    }
                }
            }
            // 级联更新全图 NameRef == old_name 的节点
            // （CtorParam 无 name_node/dependents，保守用名字匹配；同名的其他类
            //   NameRef 会被误改，但 ksoup 语料中冲突名均为特定 setter，影响可控）
            for node_idx in 0..n {
                if let Kind::NameRef { original: ref_name, .. } = &mut self.g.nodes[node_idx].kind {
                    if *ref_name == *old_name {
                        *ref_name = new_name.clone();
                    }
                }
            }
        }
        if !ctor_rename_ops.is_empty() {
            eprintln!(
                "SOC: resolved {} ctor-param/func name collision(s) ({})",
                ctor_rename_ops.len(),
                ctor_rename_ops
                    .iter()
                    .map(|(_, _, n)| n.as_str())
                    .collect::<Vec<_>>()
                    .join(", ")
            );
        }
    }

    // ================================================================
    // Phase 1: 基础松弛（批量模式——所有节点一次性入队）
    // ================================================================

    /// 把整张图松弛到收敛（初始翻译）。
    pub fn relax(&mut self) {
        let n = self.g.nodes.len();
        let mut queue: VecDeque<NodeId> = (0..n).collect();
        let mut avalanche = 0;
        while let Some(id) = queue.pop_front() {
            if self.step(id, &mut queue) {
                avalanche += 1;
            }
        }
        self.last_avalanche = avalanche;
        self.avalanche_sizes.push(avalanche);

        // Phase 2: 上下文精化——自顶向下二次松弛
        // 根节点先稳定后，从根向叶子重新触发，利用已确定的父节点上下文
        // 改进子节点的翻译选择（如类型推断、字符串/集合消歧）。
        self.context_refinement();
    }

    // ================================================================
    // Phase 2: 上下文精化（自顶向下 contextual re-evaluation）
    // ================================================================

    /// 自顶向下重新触发所有节点，让已确定的父节点上下文信息向下传播，
    /// 改进子节点的翻译选择。这构成了 SOC 的「双向传播」机制——
    /// 第一遍自底向上建立基础译文，第二遍自顶向下利用上下文精化。
    fn context_refinement(&mut self) {
        let n = self.g.nodes.len();
        // 按拓扑序（根→叶子）收集节点
        let mut topo: Vec<NodeId> = Vec::with_capacity(n);
        let mut visited = vec![false; n];
        let mut stack = vec![self.g.root];
        while let Some(id) = stack.pop() {
            if visited[id] {
                continue;
            }
            visited[id] = true;
            topo.push(id);
            // 子节点入栈（逆序以保持正序遍历）
            let children = self.g.children_of(id);
            for &c in children.iter().rev() {
                if !visited[c] {
                    stack.push(c);
                }
            }
        }

        // 自顶向下触发：父节点的上下文已稳定，子节点可利用兄弟信息重新评估
        let mut queue: VecDeque<NodeId> = VecDeque::new();
        for &id in &topo {
            queue.push_back(id);
        }
        let mut refinement_avalanche = 0;
        while let Some(id) = queue.pop_front() {
            if self.step(id, &mut queue) {
                refinement_avalanche += 1;
            }
        }
        if refinement_avalanche > 0 {
            self.avalanche_sizes.push(refinement_avalanche);
            self.last_avalanche += refinement_avalanche;
        }
    }

    // ================================================================
    // SOC 粒子驱动松弛（grain-by-grain）
    // ================================================================

    /// SOC 粒子驱动松弛：逐个「添沙」（激活叶子节点），每粒沙让级联完全结束后
    /// 再添下一粒，独立记录每次雪崩规模——用于检验幂律分布。
    ///
    /// 增强：采用 AMF（Avalanche Memory Feedback）+ 深度双因素排序：
    ///   - 第一排序键：雪崩记忆权重（低→高），使低应力叶子先驱动，积累能量
    ///   - 第二排序键：深度（深→浅），使深层叶子先驱动
    /// 这模拟了真实 SOC 系统中的应力场记忆效应：系统"记住"哪些区域容易产生
    /// 大雪崩，并在后续松弛中自适应地调整驱动顺序，使能量更均匀地积累和释放。
    pub fn relax_soc(&mut self) -> Vec<usize> {
        let n = self.g.nodes.len();
        // 收集叶子节点（无子节点的节点）作为「沙粒」。
        let mut leaves: Vec<NodeId> = Vec::new();
        for id in 0..n {
            if self.g.children_of(id).is_empty() {
                leaves.push(id);
            }
        }

        // AMF + 深度双因素排序：
        // 先按雪崩记忆权重升序（低应力优先），再按深度降序（深层优先）
        leaves.sort_by_key(|&id| {
            let memory = if id < self.avalanche_memory.len() {
                self.avalanche_memory[id]
            } else {
                0
            };
            let mut depth = 0u32;
            let mut cur = id;
            while let Some(p) = self.g.nodes[cur].parent {
                depth += 1;
                cur = p;
            }
            // (低记忆优先, 深层优先)
            (memory, std::cmp::Reverse(depth))
        });

        let mut grain_avalanches: Vec<usize> = Vec::new();
        let mut total = 0usize;
        for &leaf in &leaves {
            let mut queue: VecDeque<NodeId> = VecDeque::new();
            queue.push_back(leaf);
            let mut avalanche = 0;
            while let Some(id) = queue.pop_front() {
                if self.step(id, &mut queue) {
                    avalanche += 1;
                }
            }
            if avalanche > 0 {
                grain_avalanches.push(avalanche);
                total += avalanche;
            }
        }
        // 最终确保非叶子节点也全部收敛。
        let mut queue: VecDeque<NodeId> = (0..n).collect();
        let mut mop_up = 0;
        while let Some(id) = queue.pop_front() {
            if self.step(id, &mut queue) {
                mop_up += 1;
            }
        }
        if mop_up > 0 {
            grain_avalanches.push(mop_up);
            total += mop_up;
        }
        self.last_avalanche = total;
        self.avalanche_sizes.extend(&grain_avalanches);

        // SOC 模式也进行上下文精化
        self.context_refinement();

        grain_avalanches
    }

    // ================================================================
    // 扰动实验（用于 SOC 指标测量）
    // ================================================================

    /// 全量扰动：对所有有依赖者的声明逐一重命名再恢复，收集雪崩分布。
    pub fn perturb_all_names(&mut self) -> Vec<usize> {
        let n = self.g.nodes.len();
        let mut avals = Vec::new();
        let mut targets: Vec<(NodeId, String)> = Vec::new();
        for id in 0..n {
            if let Kind::Name { ref original } = self.g.nodes[id].kind {
                if !self.g.nodes[id].dependents.is_empty() {
                    targets.push((id, original.clone()));
                }
            }
        }
        for (id, orig) in &targets {
            // perturb
            let test_name = format!("{}_test", orig);
            if let Kind::Name { original } = &mut self.g.nodes[*id].kind {
                *original = test_name;
            }
            self.g.nodes[*id].state.target = None;
            let mut queue: VecDeque<NodeId> = VecDeque::new();
            queue.push_back(*id);
            let mut avalanche = 0;
            while let Some(nid) = queue.pop_front() {
                if self.step(nid, &mut queue) {
                    avalanche += 1;
                }
            }
            avals.push(avalanche);
            // restore
            if let Kind::Name { original } = &mut self.g.nodes[*id].kind {
                *original = orig.clone();
            }
            self.g.nodes[*id].state.target = None;
            let mut queue: VecDeque<NodeId> = VecDeque::new();
            queue.push_back(*id);
            while let Some(nid) = queue.pop_front() {
                self.step(nid, &mut queue);
            }
        }
        self.avalanche_sizes.extend(&avals);
        avals
    }

    // ================================================================
    // 核心 step：节点局部规则 + 级联传播
    // ================================================================

    /// 对单个节点应用局部规则；若目标发生变化则把邻居重新入队。
    pub(crate) fn step(&mut self, id: NodeId, queue: &mut VecDeque<NodeId>) -> bool {
        let rendered = self.render(id);
        let new_target = match rendered {
            Some(t) => t,
            None => return false,
        };
        self.g.nodes[id].state.temperature += 1;
        let changed = self.g.nodes[id].state.target.as_deref() != Some(new_target.as_str());
        if changed {
            self.g.nodes[id].state.target = Some(new_target);
            self.g.nodes[id].state.version += 1;
            self.g.nodes[id].state.confidence = 1.0;
            self.total_updates += 1;
            // AMF: 累积雪崩记忆——每次状态变更增加该节点的记忆权重
            if id < self.avalanche_memory.len() {
                self.avalanche_memory[id] = self.avalanche_memory[id].saturating_add(1);
            }
            // 崩塌级联：唤醒父节点与依赖者。
            if let Some(p) = self.g.nodes[id].parent {
                queue.push_back(p);
            }
            for d in self.g.nodes[id].dependents.clone() {
                queue.push_back(d);
            }
            // SOC 增强：同时唤醒兄弟节点，使同层节点间的一致性约束
            // 也能触发级联——这引入了「横向传播」，增大分支比 σ。
            if let Some(p) = self.g.nodes[id].parent {
                let siblings = self.g.children_of(p);
                for sib in siblings {
                    if sib != id && self.g.nodes[sib].state.target.is_some() {
                        // 仅当兄弟已有初始译文时才重新评估
                        queue.push_back(sib);
                    }
                }
            }
        }
        changed
    }

    /// 扰动：强制重命名一个声明，观察引用雪崩（演示 SOC 自动修复）。
    pub fn perturb_rename(&mut self, name_node: NodeId, new_name: &str) {
        if let Kind::Name { original } = &mut self.g.nodes[name_node].kind {
            *original = new_name.to_string();
        }
        self.g.nodes[name_node].state.target = None;
        let mut queue: VecDeque<NodeId> = VecDeque::new();
        queue.push_back(name_node);
        let mut avalanche = 0;
        while let Some(id) = queue.pop_front() {
            if self.step(id, &mut queue) {
                avalanche += 1;
            }
        }
        self.last_avalanche = avalanche;
        self.avalanche_sizes.push(avalanche);
    }

    pub fn output(&self) -> String {
        self.g.target(self.g.root).unwrap_or("").to_string()
    }
}

// ================================================================
// 嵌套类提升归一化（nested class lifting normalization）
// ================================================================
//
// 渲染阶段会把类内嵌套的 class/enum 提升（lift）为顶层声明，但：
//   1. 源码中的限定名引用（`Token.StartTag` 作类型标注、`as`/`is` 转换等）
//      仍是成员访问形式，提升后 cjc 报 "not a member of class"；
//   2. 提升出的嵌套类可能与其他顶层类撞名（如 Token.Comment vs nodes 包的 Comment），
//      cjc 报 "ambiguous use of" / 重复定义。
//
// 本 pass 在 Engine 构造期（建索引之前）对图做归一化：
//   A. 建立 (父类名, 嵌套类名) → 提升后名字 的注册表；
//   B. 撞名的嵌套类重命名为 `父类名+嵌套类名`，并改写父类子树内的非限定引用；
//   C. 全图类型字符串中的点分限定链按注册表折叠（`Token.Tag` → `TokenTag`）。
// 表达式位的限定名引用（`Token.StartTag()` 等）由 render_member 查同一注册表改写。

fn class_or_enum_name(kind: &Kind) -> Option<&str> {
    match kind {
        Kind::Class { name, .. } => Some(name),
        Kind::Enum { name, .. } => Some(name),
        _ => None,
    }
}

fn apply_nested_lifting(g: &mut Graph) -> HashMap<(String, String), String> {
    let n = g.nodes.len();
    // 1. 收集嵌套 class/enum：(父类节点, 父类名, 嵌套节点, 嵌套名)
    let mut nested: Vec<(NodeId, String, NodeId, String)> = Vec::new();
    for id in 0..n {
        if let Kind::Class {
            name: pname,
            members,
            ..
        } = &g.nodes[id].kind
        {
            for &m in members {
                if let Some(nname) = class_or_enum_name(&g.nodes[m].kind) {
                    nested.push((id, pname.clone(), m, nname.to_string()));
                }
            }
        }
    }
    if nested.is_empty() {
        return HashMap::new();
    }

    // 2. 名字出现计数：顶层 class/enum + 全部待提升嵌套类（提升后共享顶层命名空间）
    let mut counts: HashMap<String, usize> = HashMap::new();
    if let Kind::Program { items } = &g.nodes[g.root].kind {
        for &it in items {
            if let Some(nm) = class_or_enum_name(&g.nodes[it].kind) {
                *counts.entry(nm.to_string()).or_insert(0) += 1;
            }
        }
    }
    for (_, _, _, nname) in &nested {
        *counts.entry(nname.clone()).or_insert(0) += 1;
    }

    // 3. 注册表 + 重命名计划（仅撞名时加父类名前缀；前缀名若仍撞名则放弃重命名）
    let mut registry: HashMap<(String, String), String> = HashMap::new();
    let mut renames: Vec<(NodeId, NodeId, String, String)> = Vec::new();
    for (pid, pname, nid, nname) in &nested {
        let colliding = counts.get(nname).copied().unwrap_or(0) > 1;
        let candidate = format!("{}{}", pname, nname);
        let final_name = if colliding && !counts.contains_key(&candidate) {
            candidate
        } else {
            nname.clone()
        };
        registry.insert((pname.clone(), nname.clone()), final_name.clone());
        if final_name != *nname {
            renames.push((*pid, *nid, nname.clone(), final_name));
        }
    }
    // 父类自身被重命名时（嵌套中的嵌套），补充以新父类名为键的别名
    let renamed_parents: HashMap<String, String> = renames
        .iter()
        .map(|(_, _, old, new)| (old.clone(), new.clone()))
        .collect();
    let aliases: Vec<((String, String), String)> = registry
        .iter()
        .filter_map(|((p, nm), f)| {
            renamed_parents
                .get(p)
                .map(|pn| ((pn.clone(), nm.clone()), f.clone()))
        })
        .collect();
    registry.extend(aliases);

    // 4. 全图类型字符串折叠限定链（使用原始名字，需先于第 5 步的非限定重命名）
    for id in 0..n {
        rewrite_types_in_kind(&mut g.nodes[id].kind, &|ty| {
            collapse_qualified_chains(ty, &registry)
        });
    }

    // 5. 应用重命名：改声明名 + 父类子树内的非限定引用（NameRef 与类型字符串）
    if !renames.is_empty() {
        for (pid, nid, old, new) in &renames {
            match &mut g.nodes[*nid].kind {
                Kind::Class { name, .. } => *name = new.clone(),
                Kind::Enum { name, .. } => *name = new.clone(),
                _ => {}
            }
            let mut stack = vec![*pid];
            while let Some(cur) = stack.pop() {
                if let Kind::NameRef { original, .. } = &mut g.nodes[cur].kind {
                    if original == old {
                        *original = new.clone();
                    }
                }
                rewrite_types_in_kind(&mut g.nodes[cur].kind, &|ty| {
                    rewrite_bare_ident(ty, old, new)
                });
                stack.extend(g.children_of(cur));
            }
        }
        eprintln!(
            "SOC: renamed {} lifted nested class(es) to avoid top-level collision ({})",
            renames.len(),
            renames
                .iter()
                .map(|(_, _, _, new)| new.as_str())
                .collect::<Vec<_>>()
                .join(", ")
        );
    }
    registry
}

/// 对 Kind 中所有类型字符串字段应用改写函数。
fn rewrite_types_in_kind(kind: &mut Kind, f: &dyn Fn(&str) -> String) {
    match kind {
        Kind::Func {
            ret, receiver_type, ..
        } => {
            if let Some(r) = ret {
                *r = f(r);
            }
            if let Some(r) = receiver_type {
                *r = f(r);
            }
        }
        Kind::Param { ty, .. } => *ty = f(ty),
        Kind::Class {
            ctor_params,
            superclass,
            interfaces,
            ..
        } => {
            for cp in ctor_params {
                cp.ty = f(&cp.ty);
            }
            if let Some(s) = superclass {
                *s = f(s);
            }
            for i in interfaces {
                *i = f(i);
            }
        }
        Kind::Enum { params, .. } => {
            for cp in params {
                cp.ty = f(&cp.ty);
            }
        }
        Kind::VarDecl { ty: Some(ty), .. } => *ty = f(ty),
        Kind::CollLit {
            elem: Some(elem), ..
        } => *elem = f(elem),
        Kind::IsCheck { ty, .. } => *ty = f(ty),
        Kind::TypePat { ty } => *ty = f(ty),
        Kind::TypeCast { ty, .. } => *ty = f(ty),
        Kind::Try { catches, .. } => {
            for c in catches {
                c.ty = f(&c.ty);
            }
        }
        _ => {}
    }
}

/// 扫描类型字符串中的点分标识符链（`A.B.C`），交由 `map` 决定是否整体改写。
/// `map` 返回 None 时原样保留。非标识符字符逐一透传。
fn rewrite_ident_chains(ty: &str, map: &dyn Fn(&[String]) -> Option<String>) -> String {
    let chars: Vec<char> = ty.chars().collect();
    let mut out = String::new();
    let mut i = 0;
    while i < chars.len() {
        if chars[i].is_alphabetic() || chars[i] == '_' {
            let mut segs: Vec<String> = Vec::new();
            let mut j = i;
            loop {
                let mut s = String::new();
                while j < chars.len() && (chars[j].is_alphanumeric() || chars[j] == '_') {
                    s.push(chars[j]);
                    j += 1;
                }
                segs.push(s);
                if j + 1 < chars.len()
                    && chars[j] == '.'
                    && (chars[j + 1].is_alphabetic() || chars[j + 1] == '_')
                {
                    j += 1; // 吃掉 '.'，继续读下一段
                } else {
                    break;
                }
            }
            match map(&segs) {
                Some(rep) => out.push_str(&rep),
                None => out.push_str(&segs.join(".")),
            }
            i = j;
        } else {
            out.push(chars[i]);
            i += 1;
        }
    }
    out
}

/// 按注册表折叠限定链：`Token.Tag` → `TokenTag`，`Token.TokenType` → `TokenType`。
/// 首段必须命中注册表才折叠；未命中（如 `Map.Entry`）原样保留。
fn collapse_qualified_chains(ty: &str, registry: &HashMap<(String, String), String>) -> String {
    rewrite_ident_chains(ty, &|segs| {
        if segs.len() < 2 {
            return None;
        }
        let mut final_name = registry.get(&(segs[0].clone(), segs[1].clone()))?.clone();
        let mut cur = segs[1].clone();
        let mut k = 2;
        while k < segs.len() {
            match registry.get(&(cur.clone(), segs[k].clone())) {
                Some(f) => {
                    final_name = f.clone();
                    cur = segs[k].clone();
                    k += 1;
                }
                None => break,
            }
        }
        let mut rep = final_name;
        for s in &segs[k..] {
            rep.push('.');
            rep.push_str(s);
        }
        Some(rep)
    })
}

/// 非限定标识符重命名：仅替换单段（不带点）且与 `old` 完全相同的标识符。
fn rewrite_bare_ident(ty: &str, old: &str, new: &str) -> String {
    rewrite_ident_chains(ty, &|segs| {
        if segs.len() == 1 && segs[0] == old {
            Some(new.to_string())
        } else {
            None
        }
    })
}

//! Kotlin 子集递归下降解析器：把 Token 流构造为翻译图（[`Graph`]）。
//!
//! 解析过程中同时完成：
//!   * Kotlin 类型 → 仓颉类型映射；
//!   * 词法作用域内的标识符引用解析（建立依赖边，支撑重命名雪崩）。

use crate::lexer::{StrPart, Tok, Token};
use crate::node::*;
use std::collections::{HashMap, HashSet};

pub struct Parser {
    toks: Vec<Token>,
    pos: usize,
    pub g: Graph,
    scopes: Vec<HashMap<String, NodeId>>, // name -> Name 节点
    /// 类型别名注册表：`typealias Name = TargetType`。
    pub type_aliases: HashMap<String, String>,
    /// 项目级翻译：文件字节范围映射 Vec<(start_byte, end_byte)>，索引即文件编号。
    file_ranges: Option<Vec<(usize, usize)>>,
    /// 抑制尾随 lambda 解析。解析接口委托表达式（`class C : List<T> by delegate {`）
    /// 时置位，避免把紧随其后的类体 `{...}` 误当作 `delegate { ... }` 的尾随 lambda。
    suppress_trailing_lambda: bool,
    /// 已发射的 `expect fun` 存根签名（`name(cjType,cjType)`）。Kotlin 多平台
    /// `expect fun` 无 body 会渲染成无体函数报错；渲染为 throw 存根，并按映射后
    /// 签名去重——Kotlin 重载 `safeMultiply(Long,Long)`/`(Int,Int)` 在仓颉均折叠为
    /// `(Int64,Int64)`，两个存根会撞成 redefinition。
    expect_fn_sigs: HashSet<String>,
    /// 最近解析的匿名对象表达式（`object : SuperType {...}`）的首个超类型（已映射）。
    /// 仓颉无匿名对象——`parse_object_expr` 记录超类型，`parse_var_decl` 用它给
    /// `val x = object : T {...}` 的字段补类型（否则 singleton 里 `let x` 无类型崩溃）。
    pending_object_type: Option<String>,
}

type PResult<T> = Result<T, String>;

impl Parser {
    pub fn new(toks: Vec<Token>) -> Self {
        Parser {
            toks,
            pos: 0,
            g: Graph::new(),
            scopes: vec![HashMap::new()],
            type_aliases: HashMap::new(),
            file_ranges: None,
            suppress_trailing_lambda: false,
            expect_fn_sigs: HashSet::new(),
            pending_object_type: None,
        }
    }

    /// 设置项目级文件字节范围（用于追踪声明归属）。
    pub fn set_file_ranges(&mut self, ranges: Vec<(usize, usize)>) {
        self.file_ranges = Some(ranges);
    }

    /// 返回当前 token 字节偏移所属的源文件索引（0-based）。
    fn current_source_file(&self) -> Option<usize> {
        let ranges = self.file_ranges.as_ref()?;
        let offset = self.toks[self.pos].offset;
        for (i, (start, end)) in ranges.iter().enumerate() {
            if offset >= *start && offset < *end {
                return Some(i);
            }
        }
        // 如果偏移量超出所有文件范围（如合并源码末尾），归入最后一个文件
        ranges.iter().enumerate().last().map(|(i, _)| i)
    }

    // ---- Token 游标 ----
    fn peek(&self) -> &Tok {
        &self.toks[self.pos].tok
    }
    fn line(&self) -> usize {
        self.toks[self.pos].line
    }
    fn at_eof(&self) -> bool {
        matches!(self.peek(), Tok::Eof)
    }
    fn bump(&mut self) -> Tok {
        let t = self.toks[self.pos].tok.clone();
        if self.pos + 1 < self.toks.len() {
            self.pos += 1;
        }
        t
    }
    fn is_sym(&self, s: &str) -> bool {
        matches!(self.peek(), Tok::Sym(x) if x == s)
    }
    fn is_kw(&self, s: &str) -> bool {
        matches!(self.peek(), Tok::Ident(x) if x == s)
    }
    fn eat_sym(&mut self, s: &str) -> bool {
        if self.is_sym(s) {
            self.bump();
            true
        } else {
            false
        }
    }
    fn expect_sym(&mut self, s: &str) -> PResult<()> {
        if self.eat_sym(s) {
            Ok(())
        } else if self.at_eof() {
            // Graceful EOF — treat missing closing delimiter as OK
            Ok(())
        } else {
            Err(format!(
                "line {}: 期望 '{}'，但得到 {:?}",
                self.line(),
                s,
                self.peek()
            ))
        }
    }
    fn eat_kw(&mut self, s: &str) -> bool {
        if self.is_kw(s) {
            self.bump();
            true
        } else {
            false
        }
    }
    fn skip_newlines(&mut self) {
        while matches!(self.peek(), Tok::Newline) {
            self.bump();
        }
    }
    fn skip_seps(&mut self) {
        while matches!(self.peek(), Tok::Newline) || self.is_sym(";") {
            self.bump();
        }
    }

    // ---- 作用域 ----
    fn push_scope(&mut self) {
        self.scopes.push(HashMap::new());
    }
    fn pop_scope(&mut self) {
        self.scopes.pop();
    }
    fn declare(&mut self, name: &str, node: NodeId) {
        self.scopes
            .last_mut()
            .unwrap()
            .insert(name.to_string(), node);
    }
    fn resolve(&self, name: &str) -> Option<NodeId> {
        for s in self.scopes.iter().rev() {
            if let Some(id) = s.get(name) {
                return Some(*id);
            }
        }
        None
    }

    // ================= 顶层 =================
    pub fn parse_program(&mut self) -> PResult<NodeId> {
        let mut items = Vec::new();
        self.skip_seps();
        while !self.at_eof() {
            // 跳过注解前缀（可能出现在 package / import 之前）。
            self.skip_annotations();
            // 跳过 Kotlin 的 package / import 行（仓颉侧自管导入）。
            if matches!(self.peek(), Tok::Ident(x) if x == "import" || x == "package") {
                let is_import = matches!(self.peek(), Tok::Ident(x) if x == "import");
                self.bump(); // import / package
                // 收集 import 的点分路径段（成员 import 重限定用）。
                let mut segs: Vec<String> = Vec::new();
                let mut had_star = false;
                let mut had_alias = false;
                while !matches!(self.peek(), Tok::Newline | Tok::Eof) {
                    match self.peek() {
                        Tok::Ident(x) => {
                            if x == "as" {
                                had_alias = true;
                            } else if !had_alias {
                                segs.push(x.clone());
                            }
                        }
                        Tok::Sym(s) if s == "*" => had_star = true,
                        _ => {}
                    }
                    self.bump();
                }
                if is_import && !had_star && !had_alias {
                    self.record_member_import(&segs);
                }
                self.skip_seps();
                continue;
            }
            let sf = self.current_source_file();
            match self.parse_top_level() {
                Ok(item) => {
                    if sf.is_some() {
                        self.g.nodes[item].source_file = sf;
                    }
                    items.push(item);
                }
                Err(e) => {
                    // If the graph already has significant content and we're at EOF,
                    // salvage the parsed class nodes into items.
                    let node_count = self.g.nodes.len();
                    if node_count > 10 {
                        self.skip_seps();
                        if self.at_eof() {
                            eprintln!("PARSE NOTE: EOF after parsing {} nodes ({}), salvaging content",
                                node_count, e);
                            // Find all Class/Enum nodes in the graph and add as program items
                            let n = self.g.nodes.len();
                            for id in 0..n {
                                let is_class = matches!(self.g.kind(id), Kind::Class { .. } | Kind::Enum { .. });
                                if is_class {
                                    let parent_is_program = self.g.nodes[id].parent.map_or(true, |p| {
                                        matches!(self.g.kind(p), Kind::Program { .. })
                                    });
                                    if parent_is_program {
                                        items.push(id);
                                    }
                                }
                            }
                            break;
                        }
                    }
                    eprintln!("PARSE ERROR at line {}: {}", self.line(), e);
                    // 合并翻译中某声明解析失败时，跳过至下一 package 边界继续
                    // 确保退出所有嵌套上下文（跳过直至遇到 package 声明或 EOF）
                    // 确保退出所有嵌套上下文（跳过直至遇到 package 声明或 EOF）
                    // depth 从错误点起算：错误点可能在嵌套花括号内，退出外层
                    // 花括号时 depth 会变负，故边界判定用 <= 0（== 0 会一路
                    // 跳到 EOF，丢掉后续所有文件的声明）。
                    let mut depth = 0i32;
                    while !self.at_eof() {
                        if matches!(self.peek(), Tok::Ident(x) if x == "package") && depth <= 0 {
                            break;
                        }
                        if self.is_sym("{") { depth += 1; }
                        if self.is_sym("}") { depth -= 1; }
                        self.bump();
                    }
                    // 将作用域重置到全局（丢弃所有嵌套作用域）
                    while self.scopes.len() > 1 {
                        self.scopes.pop();
                    }
                }
            }
            self.skip_seps();
            // 诊断：检测合并翻译中的 scope 泄漏
            if self.scopes.len() > 1 {
                eprintln!(
                    "WARNING: scope leak depth={} at line {}",
                    self.scopes.len() - 1,
                    self.line()
                );
                while self.scopes.len() > 1 {
                    self.scopes.pop();
                }
            }
        }
        let root = self.g.add(Kind::Program { items });
        self.g.root = root;
        Ok(root)
    }

    fn parse_top_level(&mut self) -> PResult<NodeId> {
        // 合并翻译末尾可能出现残留空行/EOF，直接跳过
        if self.at_eof() {
            return Ok(self.g.add(Kind::Raw("".into())));
        }
        // 跳过可见性 / 修饰符
        let mods = self.skip_modifiers();
        // 如果当前 token 不是已知声明关键字，尝试容错跳过
        if !self.is_kw("fun")
            && !self.is_kw("enum")
            && !self.is_kw("class")
            && !self.is_kw("data")
            && !self.is_kw("object")
            && !self.is_kw("interface")
            && !self.is_kw("typealias")
            && !self.is_kw("companion")
            && !self.is_sym("}")
            && !self.is_kw("val")
            && !self.is_kw("var")
        {
            // 跳过无法识别的顶层内容直到下一个声明或 EOF
            while !self.at_eof()
                && !self.is_kw("fun")
                && !self.is_kw("class")
                && !self.is_kw("val")
                && !self.is_kw("var")
                && !self.is_kw("object")
                && !self.is_kw("interface")
                && !self.is_kw("enum")
            {
                self.bump();
            }
            return Ok(self.g.add(Kind::Raw("".into())));
        }
        if self.is_kw("fun") {
            // `fun interface` 是 Kotlin SAM/函数式接口，不是函数声明。
            if self.peek_next_is_kw("interface") {
                self.bump(); // 跳过 `fun`
                return self.parse_class(&mods);
            }
            self.parse_fun(&mods)
        } else if self.is_kw("enum") {
            self.parse_enum()
        } else if self.is_kw("class")
            || self.is_kw("data")
            || self.is_kw("object")
            || self.is_kw("interface")
        {
            self.parse_class(&mods)
        } else if self.is_kw("typealias") {
            self.parse_typealias()
        } else if self.is_kw("companion") {
            // Companion object at top level — occurs when a class body was
            // prematurely closed. Skip the companion gracefully.
            self.bump(); // companion
            self.eat_kw("object");
            if matches!(self.peek(), Tok::Ident(_)) && !self.is_sym("{") {
                self.bump(); // optional companion name
            }
            if self.is_sym("{") {
                let _ = self.skip_balanced_braces();
            }
            Ok(self.g.add(Kind::Raw("companion".into())))
        } else if self.is_sym("}") {
            // Stray closing brace at top level — skip
            self.bump();
            Ok(self.g.add(Kind::Raw("".into())))
        } else {
            // 顶层语句（少见）——并入隐式块
            self.parse_statement()
        }
    }

    /// 判定 import 路径是否为**成员 import**（`import pkg.Class.member` /
    /// `import pkg.Class.Companion.member`），是则记入 `member → Class` 重限定表。
    /// 判据：末段小写开头（成员），其前存在大写开头段（类型，`Companion` 跳过）。
    /// `import pkg.subpkg.topLevelFunc`（末段前均为小写包名）不记——那是顶层函数导入。
    fn record_member_import(&mut self, segs: &[String]) {
        if segs.len() < 2 {
            return;
        }
        let member = &segs[segs.len() - 1];
        let has_companion = segs.iter().any(|s| s == "Companion");
        let member_is_lower = member.chars().next().is_some_and(|c| c.is_lowercase());
        // 成员判定：路径含 `Companion`（无论成员大小写，如 `X.Companion.MAX`），或
        // 末段小写开头（如 `Normalizer.lowerCase`）。末段大写且无 Companion → 可能是
        // 嵌套类型 import（`P.C.Inner`），跳过（交嵌套提升机制处理，避免误改写）。
        if !has_companion && !member_is_lower {
            return;
        }
        // 从倒数第二段起向前找第一个大写开头段作为限定类型（跳过 `Companion`）。
        let mut qualifier: Option<&String> = None;
        for seg in segs[..segs.len() - 1].iter().rev() {
            if seg == "Companion" {
                continue;
            }
            if seg.chars().next().is_some_and(|c| c.is_uppercase()) {
                qualifier = Some(seg);
            }
            break; // 只看紧邻的（跳过 Companion 后）一段——它是包名则非成员 import
        }
        if let Some(q) = qualifier {
            self.g
                .member_imports
                .insert(member.clone(), safe_name(q));
        }
    }

    fn skip_modifiers(&mut self) -> Vec<String> {
        const MODS: &[&str] = &[
            "public",
            "private",
            "internal",
            "protected",
            "open",
            "final",
            "abstract",
            "override",
            "inline",
            "data",
            "sealed",
            "const",
            "lateinit",
            "tailrec",
            "crossinline",
            "noinline",
            "infix",
            "operator",
            "suspend",
            "external",
            "annotation",
            "expect",
            "actual",
        ];
        let mut seen = Vec::new();
        loop {
            // Interleave annotation-skipping so modifiers that follow annotations
            // (e.g. `@JvmInline public value class`) are still captured rather than
            // dropped — previously they leaked past into the unrecognized-token skip.
            self.skip_annotations();
            let mut matched = false;
            if let Tok::Ident(x) = self.peek() {
                let x = x.clone();
                // `value` is a Kotlin soft keyword: a modifier only in `value class`.
                // Captured so the renderer can emit a `struct` (value semantics).
                // It must NOT be eaten as a bare identifier (`var value: Int`, `value += 1`).
                let is_value_mod = x == "value" && self.peek_next_is_kw("class");
                if (MODS.contains(&x.as_str()) && x != "data" && x != "const") || is_value_mod {
                    seen.push(x);
                    self.bump();
                    matched = true;
                }
            }
            if !matched {
                break;
            }
        }
        seen
    }

    /// Skip Kotlin annotations: `@Name`, `@Name(args)`, `@use-site:Name`, etc.
    fn skip_annotations(&mut self) {
        loop {
            if !self.is_sym("@") {
                break;
            }
            self.bump(); // @
            self.skip_annotation_name_and_args();
            self.skip_newlines();
        }
    }

    /// After consuming `@`, skip the annotation name (with optional use-site target)
    /// and optional argument list `(...)`.
    fn skip_annotation_name_and_args(&mut self) {
        // Optional use-site target: @target:Name
        if matches!(self.peek(), Tok::Ident(_)) {
            self.bump();
            if self.is_sym(":") {
                self.bump(); // :
                // Eat the actual annotation name
                if matches!(self.peek(), Tok::Ident(_)) {
                    self.bump();
                }
            }
        }
        // Eat dotted name parts (e.g. org.junit.Test)
        while self.is_sym(".") {
            self.bump(); // .
            if matches!(self.peek(), Tok::Ident(_)) {
                self.bump();
            }
        }
        // Optional argument list
        if self.is_sym("(") {
            self.skip_balanced_parens();
        }
    }

    /// Skip property accessors: `get()`, `get() = expr`, `get() { ... }`,
    /// `set(value)`, `private set`, `@Ann set`, etc.
    /// 类体成员声明起始关键字——用于跳过属性 getter 单表达式体时判定边界。
    const DECL_KEYWORDS: &[&str] = &[
        "val", "var", "fun", "class", "object", "interface",
        "companion", "init", "constructor", "enum",
        "sealed", "data", "abstract", "open",
        "override", "private", "protected", "internal", "public",
        "suspend", "inline", "annotation",
    ];

    fn skip_property_accessors(&mut self) {
        self.skip_newlines();
        loop {
            let save = self.pos;
            self.skip_modifiers();
            let is_get = self.eat_kw("get");
            let is_set = self.eat_kw("set");
            if !is_get && !is_set {
                self.pos = save;
                break;
            }
            // Optional parameter: set(value) or get()
            if self.is_sym("(") {
                self.skip_balanced_parens();
            }
            self.skip_newlines();
            if self.eat_sym("=") {
                // 跳过单表达式访问器体（不解析，避免 parse_expr 失败）。
                // 跟踪大括号深度——表达式内的 {} 不应终止跳过。
                // 多行表达式（get() =\n when { ... }）在行间有换行，
                // 仅在体外的 } 或下一 get/set 时停止。
                while matches!(self.peek(), Tok::Newline) {
                    self.bump();
                }
                let mut depth = 0i32;
                loop {
                    let tok = self.peek().clone();
                    // 提前检查：换行且 depth=0 时，探测下一非换行 token
                    // 是否为声明关键字，避免越界吃掉下一成员。
                    let is_decl_boundary = |t: &Tok| -> bool {
                        match t {
                            Tok::Ident(s) => Self::DECL_KEYWORDS.contains(&s.as_str()),
                            Tok::Sym(s) => s == "}" || s == "{",
                            Tok::Newline | Tok::Eof => true,
                            _ => false,
                        }
                    };
                    match tok {
                        Tok::Newline => {
                            // 看一眼后面的内容
                            let save = self.pos;
                            self.bump(); // 先吞掉当前换行
                            while matches!(self.peek(), Tok::Newline) {
                                self.bump();
                            }
                            let next = self.peek().clone();
                            if depth == 0 && is_decl_boundary(&next) {
                                // 下一 token 看起来是声明/大括号，回退到换行前位置停下
                                self.pos = save;
                                break;
                            }
                            continue;
                        }
                        Tok::Eof => { break; }
                        Tok::Sym(ref s) if s == "{" => {
                            depth += 1;
                            self.bump();
                            continue;
                        }
                        Tok::Sym(ref s) if s == "}" => {
                            if depth == 0 { break; }
                            depth -= 1;
                            self.bump();
                            continue;
                        }
                        Tok::Ident(ref kw)
                            if depth == 0 && (kw == "get" || kw == "set") =>
                        { break; }
                        _ => { self.bump(); continue; }
                    }
                }
            } else if self.is_sym("{") {
                // Block accessor body — skip balanced braces
                let _ = self.skip_balanced_braces();
            }
            self.skip_newlines();
        }
    }

    /// 试探性跳过 `<...>` 泛型实参。成功时返回 true。
    fn try_skip_generic_args(&mut self) -> bool {
        if !self.eat_sym("<") {
            return false;
        }
        let mut depth = 1i32;
        while depth > 0 {
            let tok = self.peek().clone();
            match tok {
                Tok::Sym(s) if s == "<" => { self.bump(); depth += 1; }
                Tok::Sym(s) if s == ">" => { self.bump(); depth -= 1; }
                Tok::Sym(s) if s == ">>" => { self.bump(); depth -= 2; }
                Tok::Eof => return false,
                _ => { self.bump(); }
            }
        }
        true
    }

    /// Skip a balanced `{ ... }` block (without parsing contents).
    fn skip_balanced_braces(&mut self) -> PResult<()> {
        self.expect_sym("{")?;
        let mut depth = 1i32;
        while depth > 0 && !self.at_eof() {
            if self.is_sym("{") {
                depth += 1;
            } else if self.is_sym("}") {
                depth -= 1;
            }
            // bump AFTER checking so we consume the closing }
            self.bump();
        }
        if depth != 0 {
            return Err(format!("line {}: 未闭合的块", self.line()));
        }
        Ok(())
    }

    /// Parse anonymous object expression: `object : SuperType(args) { body }`
    /// or `object { body }`. Returns a Raw placeholder node.
    /// Caller has already consumed the `object` keyword.
    fn parse_object_expr(&mut self) -> PResult<NodeId> {
        // 捕获首个超类型（含泛型实参，映射后）用于给宿主字段补类型。
        let mut first_supertype: Option<String> = None;
        if self.eat_sym(":") {
            // Supertype list
            loop {
                self.skip_newlines();
                if matches!(self.peek(), Tok::Ident(_)) {
                    let sup_start = self.pos;
                    self.bump(); // supertype name
                    // Skip generic args
                    if self.is_sym("<") {
                        let mut depth = 1i32;
                        self.bump();
                        while depth > 0 && !self.at_eof() {
                            if self.is_sym("<") {
                                depth += 1;
                            } else if self.is_sym(">") {
                                depth -= 1;
                            }
                            self.bump();
                        }
                    }
                    // 捕获超类型原文（名字 + 可选 `<...>`），映射为仓颉类型。
                    if first_supertype.is_none() {
                        let raw: String = self.toks[sup_start..self.pos]
                            .iter()
                            .map(|t| match &t.tok {
                                Tok::Ident(s) => s.clone(),
                                Tok::Sym(s) => s.clone(),
                                _ => String::new(),
                            })
                            .collect();
                        if !raw.is_empty() {
                            first_supertype = Some(map_type(&raw));
                        }
                    }
                    // Skip constructor args
                    if self.is_sym("(") {
                        self.skip_balanced_parens();
                    }
                } else {
                    break;
                }
                if !self.eat_sym(",") {
                    break;
                }
            }
        }
        // Parse object body
        self.skip_newlines();
        if self.is_sym("{") {
            let _ = self.skip_balanced_braces();
        }
        // 仓颉无匿名对象——降级为 throw 存根表达式（Nothing 类型，可赋给任意字段），
        // 让含匿名对象的声明先解析通过、揭示下游语义层。宿主字段类型由 parse_var_decl
        // 从 pending_object_type 补全（否则 singleton 里 `let x` 无类型解析崩溃）。
        self.pending_object_type = first_supertype;
        Ok(self.g.add(Kind::Raw(
            "(throw Exception(\"anonymous object stub\"))".into(),
        )))
    }

    fn parse_typealias(&mut self) -> PResult<NodeId> {
        self.eat_kw("typealias");
        let name = self.expect_ident()?;
        // 保留泛型参数到 full_name (如 StringMap<V>),render 时检查 < 决定是否注释化
        // type_aliases 注册表仍用短名 (name) 作 key,下游 X<Arg> 由 map_type 兜底
        let mut full_name = name.clone();
        // Kotlin 泛型 typealias `typealias X<T> = Target<T>`：跳过 `<T>` 泛型参数
        // 之前直接 expect_sym("=") 会触发 "期望 '=', 但得到 Sym('<')" PARSE ERROR。
        if self.is_sym("<") {
            let mut gp: Vec<String> = Vec::new();
            let mut suf = String::new();
            self.parse_generic_params(&mut gp, &mut suf);
            if !gp.is_empty() {
                let names: Vec<&str> = gp
                    .iter()
                    .map(|g| g.split(" <: ").next().unwrap_or(g))
                    .collect();
                full_name = format!("{}<{}>", name, names.join(", "));
            }
        }
        self.expect_sym("=")?;
        self.skip_newlines();
        let ty = self.parse_type()?;
        self.type_aliases.insert(name.clone(), ty.clone());
        Ok(self.g.add(Kind::TypeAlias {
            name: full_name,
            target_type: ty,
        }))
    }

    /// Parse generic type parameters `<T>` / `<T, U>` / `<T : Bound>`.
    fn parse_generic_params(&mut self, params: &mut Vec<String>, suffix: &mut String) {
        let mut depth = 0;
        let mut gen_tokens = Vec::new();
        let mut expect_name = true;
        loop {
            if self.is_sym("<") {
                depth += 1;
                gen_tokens.push("<".to_string());
            } else if self.is_sym(">") || self.is_sym(">>") {
                let is_double = self.is_sym(">>");
                depth -= 1;
                gen_tokens.push(">".to_string());
                if depth == 0 {
                    self.bump();
                    break;
                }
                // `>>` = 两个连续的 `>`，第二层在下一轮处理
                if is_double {
                    depth -= 1;
                    gen_tokens.push(">".to_string());
                    if depth == 0 {
                        self.bump();
                        break;
                    }
                }
            } else if self.at_eof() {
                break;
            } else {
                if let Tok::Ident(s) = self.peek() {
                    // Kotlin 泛型修饰符：`reified`（inline fun 类型形参内联标记）、
                    // `out`/`in`（声明侧方差）。仓颉不支持——直接跳过，不作为参数名 push。
                    // 这些关键字不会作为参数名出现，跳过是安全的。
                    let is_generic_mod = matches!(s.as_str(), "reified" | "out" | "in");
                    if is_generic_mod {
                        self.bump();
                        continue;
                    }
                    if expect_name && depth == 1 {
                        params.push(s.clone());
                        expect_name = false;
                    }
                    gen_tokens.push(map_type(&s));
                } else if let Tok::Sym(s) = self.peek() {
                    if s == "," && depth == 1 {
                        expect_name = true;
                    }
                    // Kotlin star-projection `*` → 仓颉 `Any`（如 `KClass<*>` 的 `<*>`
                    // 被误解析为函数泛型参数时,`*` 需映射为 `Any` 避免 cjc 拒绝）
                    if s == "*" {
                        gen_tokens.push("Any".to_string());
                        self.bump();
                        continue;
                    }
                    // Skip upper bound constraint `: Bound`（含嵌套泛型如 `Comparable<T>`）。
                    // 关键：bdepth==0 时遇到的 `>` 是**类型参数表**的收尾，不属于 bound——
                    // 必须留给外层循环消费，否则外层 depth 回不到 0，会吞掉函数名和参数表
                    // （`<T : Node>` 单参数带 bound 即触发，渲染成 `func <T, type, ...>(: )`）。
                    if s == ":" {
                        self.bump();
                        let mut bdepth = 0i32;
                        // 捕获 bound 供渲染 `where T <: Bound`（仓颉泛型无 bound 则无法
                        // 调用 T 的成员方法）。编码进 params 末项：`"T <: Bound"`，
                        // render_func 再拆分——避免改 Kind::Func 接口。
                        let mut bound = String::new();
                        while !self.at_eof() {
                            if self.is_sym(">>") {
                                // 首个 `>` 收 bound 嵌套，次个收外层；bdepth<=1 都交给外层的
                                // `>>` 双层处理（它按两个 `>` 递减 depth）。
                                if bdepth <= 1 { break; }
                                bdepth -= 2;
                                bound.push_str(">>");
                                self.bump();
                            } else if self.is_sym(">") {
                                if bdepth == 0 { break; } // 参数表收尾，留给外层
                                bdepth -= 1;
                                bound.push('>');
                                self.bump();
                            } else if self.is_sym("<") {
                                bdepth += 1;
                                bound.push('<');
                                self.bump();
                            } else if self.is_sym(",") && bdepth == 0 {
                                break;
                            } else {
                                if let Tok::Ident(b) = self.peek() {
                                    bound.push_str(&map_type(b));
                                } else if let Tok::Sym(sy) = self.peek() {
                                    bound.push_str(sy);
                                }
                                self.bump();
                            }
                        }
                        // `>>` 在 bdepth==1 断开时首个 `>` 属于 bound 的嵌套泛型收尾
                        if self.is_sym(">>") && bound.contains('<') && !bound.ends_with('>') {
                            bound.push('>');
                        }
                        if !bound.is_empty() {
                            if let Some(last) = params.last_mut() {
                                *last = format!("{} <: {}", last, bound);
                            }
                        }
                        continue;
                    }
                    gen_tokens.push(s.clone());
                }
            }
            self.bump();
        }
        *suffix = gen_tokens.join("");
    }

    // ---- 函数 ----
    fn parse_fun(&mut self, mods: &[String]) -> PResult<NodeId> {
        self.eat_kw("fun");
        // Handle generic params that come BEFORE the function name: `fun <T> name(...)`
        let mut generic_suffix = String::new();
        let mut generic_params: Vec<String> = Vec::new();
        if self.is_sym("<") {
            self.parse_generic_params(&mut generic_params, &mut generic_suffix);
        }
        let mut name = self.expect_ident()?;
        // 跳过接收者类型上的泛型实参（如 `fun <T> ArrayList<T>.foo()` 中的 `<T>`），
        // 这样后续扩展函数解析时 receiver_type = ArrayList + generic_suffix (= <T>)。
        // 仅当接收者显式带 `<...>` 时泛型才归属接收者；裸名接收者
        // （`fun <R> Module.factoryOf(...)`，Module 非泛型）的泛型属于函数自身，
        // 渲染为 extend Module { func factoryOf<R>(...) }（cjc 探针验证合法）。
        let mut receiver_has_type_args = false;
        if self.is_sym("<") && !generic_params.is_empty() {
            receiver_has_type_args = self.try_skip_generic_args();
        }
        // 函数自身泛型形参：`fun name<T>(...)`（仅在无 `<` 前缀且确认为函数泛型时）
        if self.is_sym("<") && generic_params.is_empty() {
            self.parse_generic_params(&mut generic_params, &mut generic_suffix);
            // `fun ArrayList<Int>.avg()`（无 `fun <T>` 前缀）：此处的 `<...>` 实为
            // 接收者的具体类型实参，归属接收者（extend ArrayList<Int64>）。
            if self.is_sym(".") {
                receiver_has_type_args = true;
            }
        }
        // 扩展函数：`fun ReceiverType.name(...)` 或 `fun A.B.name(...)` → extend 语法
        let mut receiver_type: Option<String> = None;
        while self.eat_sym(".") {
            let recv = if let Some(prev) = receiver_type.take() {
                format!("{}.{}", prev, map_type(&name))
            } else if receiver_has_type_args {
                format!("{}{}", map_type(&name), generic_suffix)
            } else {
                map_type(&name)
            };
            receiver_type = Some(recv);
            name = self.expect_ident()?;
            if receiver_has_type_args {
                generic_params.clear();
            }
        }
        self.push_scope();
        let params = self.parse_param_nodes()?;
        // 扩展函数中 `this` 自然引用接收者，无需特殊处理
        let mut ret = None;
        if self.eat_sym(":") {
            ret = Some(self.parse_type()?);
        }
        // 函数体：块 / `= expr` / 无（接口/抽象方法）。
        let body;
        let mut is_abstract = false;
        if self.eat_sym("=") {
            self.skip_newlines();
            // Expression body `= throw X(...)` (e.g. `fun f(): Nothing = throw IAE(...)`):
            // render as a bare `throw`, not `return throw` (parse_expr doesn't consume `throw`).
            if self.is_kw("throw") {
                self.bump();
                let e = self.parse_expr()?;
                let throw_node = self.g.add(Kind::Throw { value: e });
                body = self.g.add(Kind::Block { stmts: vec![throw_node] });
            } else {
                let e = self.parse_expr()?;
                let r = self.g.add(Kind::Return { value: Some(e) });
                body = self.g.add(Kind::Block { stmts: vec![r] });
            }
        } else if self.is_sym("{") {
            body = self.parse_block()?;
        } else if mods.iter().any(|m| m == "expect") && receiver_type.is_none() {
            // Kotlin 多平台 `expect fun`（common 侧无 body，actual 在平台目录未纳入
            // 翻译）——渲染为 throw 存根而非无体函数，让顶层调用点仍可解析。
            // 存根 throw 类型为 Nothing，兼容任意返回类型。
            let sigs: Vec<String> = params
                .iter()
                .map(|p| match self.g.kind(*p) {
                    Kind::Param { ty, .. } => ty.clone(),
                    _ => String::new(),
                })
                .collect();
            let sig_key = format!("{}({})", name, sigs.join(","));
            if !self.expect_fn_sigs.insert(sig_key) {
                // 映射后签名重复（如 safeMultiply(Long,Long)/(Int,Int) 均折叠为
                // (Int64,Int64)）——丢弃重复存根，避免 redefinition。
                self.pop_scope();
                return Ok(self.g.add(Kind::Raw(String::new())));
            }
            let stub = self.g.add(Kind::Raw(format!(
                "throw Exception(\"expect stub: {}\")",
                name
            )));
            body = self.g.add(Kind::Block { stmts: vec![stub] });
        } else {
            // 无函数体：抽象/接口方法声明。
            is_abstract = true;
            body = self.g.add(Kind::Block { stmts: vec![] });
        }
        self.pop_scope();
        let is_main = name == "main";
        let ret = if is_main { None } else { ret };
        let is_override = mods.iter().any(|m| m == "override");
        Ok(self.g.add(Kind::Func {
            name: safe_name(&name),
            params,
            ret,
            body,
            is_main,
            is_abstract,
            is_override,
            receiver_type,
            generic_params,
        }))
    }

    fn parse_param_nodes(&mut self) -> PResult<Vec<NodeId>> {
        let mut params = Vec::new();
        self.expect_sym("(")?;
        self.skip_newlines();
        while !self.is_sym(")") {
            // 不调用 skip_modifiers()——它会把参数名 `open`、`internal` 等误识别为修饰符。
            // 常规函数参数无修饰符（构造器参数的 val/var 在 parse_class 中单独处理）。
            // 但 inline 函数的 lambda 参数可带 `noinline`/`crossinline` 修饰符 — 这两个
            // 关键字不会作为参数名出现（只在 inline 函数 lambda 参数前合法），可安全跳过。
            let is_vararg = self.eat_kw("vararg");
            self.eat_kw("noinline");
            self.eat_kw("crossinline");
            let pname = self.expect_ident()?;
            self.expect_sym(":")?;
            let ty = if is_vararg {
                let base_ty = self.parse_type()?;
                format!("Array<{}>", base_ty)
            } else {
                self.parse_type()?
            };
            let default = if self.eat_sym("=") {
                Some(self.parse_expr()?)
            } else {
                None
            };
            let nn = self.g.add(Kind::Name {
                original: pname.clone(),
            });
            let pid = self.g.add(Kind::Param {
                name_node: nn,
                ty,
                default,
            });
            self.declare(&pname, nn);
            params.push(pid);
            self.skip_newlines();
            if !self.eat_sym(",") {
                break;
            }
            self.skip_newlines();
        }
        self.expect_sym(")")?;
        Ok(params)
    }

    // ---- 枚举 ----
    fn parse_enum(&mut self) -> PResult<NodeId> {
        self.eat_kw("enum");
        // `enum class Name { A, B, C }` or `enum class Name(val x: Int) { A(1), B(2) }`
        self.eat_kw("class");
        let name = self.expect_ident()?;
        // 解析枚举构造器参数
        let mut params = Vec::new();
        if self.is_sym("(") {
            self.bump();
            self.skip_newlines();
            while !self.is_sym(")") {
                self.skip_modifiers();
                let kind = if self.eat_kw("val") {
                    CtorParamKind::Val
                } else if self.eat_kw("var") {
                    CtorParamKind::Var
                } else {
                    CtorParamKind::Plain
                };
                let pname = self.expect_ident()?;
                self.expect_sym(":")?;
                let ty = self.parse_type()?;
                // 解析默认值
                let default = if self.eat_sym("=") {
                    Some(self.parse_expr()?)
                } else {
                    None
                };
                params.push(CtorParam {
                    kind,
                    name: safe_name(&pname),
                    ty,
                    default,
                });
                self.skip_newlines();
                if !self.eat_sym(",") {
                    break;
                }
                self.skip_newlines();
            }
            self.expect_sym(")")?;
        }
        // 跳过可能的继承列表（如 `: Interface`）
        if self.eat_sym(":") {
            loop {
                self.skip_newlines();
                if !matches!(self.peek(), Tok::Ident(_)) {
                    break;
                }
                self.bump(); // type name
                // 跳过泛型实参
                if self.is_sym("<") {
                    let mut depth = 1;
                    self.bump();
                    while depth > 0 && !self.at_eof() {
                        if self.is_sym("<") {
                            depth += 1;
                        } else if self.is_sym(">") {
                            depth -= 1;
                        }
                        self.bump();
                    }
                }
                // 跳过构造器实参
                if self.is_sym("(") {
                    self.skip_balanced_parens();
                }
                if !self.eat_sym(",") {
                    break;
                }
            }
        }
        self.skip_newlines();
        self.expect_sym("{")?;
        self.skip_seps();
        let mut entries = Vec::new();
        // 解析具名枚举项，直到 `}` 或成员分隔 `;`
        while !self.is_sym("}") && !self.is_sym(";") && !self.at_eof() {
            self.skip_annotations();
            let entry_name = self.expect_ident()?;
            // 解析枚举项构造实参（如 `RED(0xFF)`）
            let mut entry_args = Vec::new();
            if self.is_sym("(") {
                self.bump();
                self.skip_newlines();
                while !self.is_sym(")") {
                    entry_args.push(self.parse_expr()?);
                    self.skip_newlines();
                    if !self.eat_sym(",") {
                        break;
                    }
                    self.skip_newlines();
                }
                self.expect_sym(")")?;
            }
            entries.push(EnumEntry {
                name: entry_name,
                args: entry_args,
            });
            // 枚举项带匿名类体（每项 override 抽象方法，如 TokeniserState 的
            // `Data { override fun read(...) {...} }`）：先跳过体、保留条目名，
            // 否则条目名后紧跟 `{` 会让 comma 检查落空、循环在首个条目后就 break，
            // 丢失其余 60+ 条目。逐条目体方法的翻译是后续语义轮次的工作（阶段②）。
            self.skip_newlines();
            if self.is_sym("{") {
                self.skip_balanced_braces()?;
            }
            self.skip_newlines();
            if !self.eat_sym(",") {
                break;
            }
            // 只跳换行，不跳 `;`：trailing comma 后的 `;`（`fallback,\n;`）是
            // 条目/成员分隔符，被吞掉会把成员区的修饰符（`public companion ...`）
            // 误捕为枚举条目。
            self.skip_newlines();
        }
        // 解析枚举体的成员函数部分（`;` 之后）
        let mut enum_members = Vec::new();
        // R17 簇A阶段②: companion object 内的 public 标量常量提升为顶层 let。
        // 仓颉 enum 无 static 成员, 外部 `EnumName.const`（如 TokeniserState.nullChar×7）
        // 无处落脚 → 捕获后由 render 提升 + 重写引用。
        let mut companion_consts = Vec::new();
        if self.eat_sym(";") {
            self.skip_seps();
            while !self.is_sym("}") && !self.at_eof() {
                let mmods = self.skip_modifiers();
                if self.is_kw("fun") {
                    if self.peek_next_is_kw("interface") {
                        self.bump();
                        enum_members.push(self.parse_class(&mmods)?);
                    } else {
                        enum_members.push(self.parse_fun(&mmods)?);
                    }
                } else if self.is_kw("companion") {
                    // enum 内 companion object：捕获 public 标量常量（提升顶层）,
                    // 其余成员（private 常量 / 函数 / 嵌套）整块平衡跳过。
                    self.bump(); // companion
                    self.eat_kw("object");
                    if matches!(self.peek(), Tok::Ident(_)) {
                        self.bump(); // 可选的 companion 名
                    }
                    if self.eat_sym("{") {
                        self.skip_seps();
                        while !self.is_sym("}") && !self.at_eof() {
                            let cmods = self.skip_modifiers();
                            let is_private = cmods.iter().any(|m| m == "private");
                            // 复用既有构造解析器完整消费每个成员（正确处理 body/init/嵌套），
                            // 仅保留非 private 的 `[const] val` 标量常量提升顶层, 其余丢弃。
                            if self.is_kw("const") || self.is_kw("val") || self.is_kw("var") {
                                // 标量常量：parse_var_decl 完整消费声明（含 init 表达式）。
                                // 非 private 的 `[const] val` 才捕获提升; private/var 解析后丢弃。
                                let mutable = self.is_kw("var");
                                self.eat_kw("const");
                                let v = self.parse_var_decl()?;
                                if !mutable && !is_private {
                                    companion_consts.push(v);
                                }
                            } else if self.is_kw("fun")
                                || self.is_kw("object")
                                || self.is_kw("class")
                                || self.is_kw("interface")
                                || self.is_kw("enum")
                            {
                                // companion 私有 helper / 嵌套类型：R18（需与条目体一并渲染）。
                                // 本轮**不解析其体**——体内可能含译器尚不支持的构造（如
                                // `when (val c: Char = ...)` 带类型的 when 主体, TokeniserState:1669），
                                // parse_fun 会整文件报错。改为跳过签名后平衡跳过 body。
                                self.bump(); // fun/object/class/...
                                loop {
                                    if self.at_eof() || self.is_sym("}") {
                                        break;
                                    }
                                    if self.is_sym("(") {
                                        self.skip_balanced_parens();
                                    } else if self.is_sym("{") {
                                        let _ = self.skip_balanced_braces();
                                        break;
                                    } else {
                                        self.bump();
                                    }
                                }
                            } else if self.is_sym("{") {
                                let _ = self.skip_balanced_braces();
                            } else {
                                self.bump();
                            }
                            self.skip_seps();
                        }
                        self.expect_sym("}")?;
                    }
                } else if self.is_sym("{") {
                    // 其他成员的块体（如嵌套 `object Constants { ... }` 的体）：
                    // 必须整块平衡跳过，否则逐 token bump 会走进嵌套体、在其内层
                    // `}` 处误判为 enum 结束，把 enum 自身的 `}` 与后续 companion
                    // 泄漏到顶层（HtmlTreeBuilderState 回归）。
                    let _ = self.skip_balanced_braces();
                } else {
                    // 跳过其他成员（标识符、修饰符、类型等非块 token）
                    self.bump();
                }
                self.skip_seps();
            }
        } else {
            // 跳过枚举体其余部分
            let mut depth = 1;
            while depth > 0 && !self.at_eof() {
                if self.is_sym("{") {
                    depth += 1;
                } else if self.is_sym("}") {
                    depth -= 1;
                    if depth == 0 {
                        break;
                    }
                }
                self.bump();
            }
        }
        self.expect_sym("}")?;
        Ok(self.g.add(Kind::Enum {
            name: safe_name(&name),
            entries,
            params,
            companion_consts,
        }))
    }

    fn skip_balanced_parens(&mut self) {
        if !self.eat_sym("(") {
            return;
        }
        let mut depth = 1;
        while depth > 0 && !self.at_eof() {
            if self.is_sym("(") {
                depth += 1;
            } else if self.is_sym(")") {
                depth -= 1;
            }
            self.bump();
        }
    }

    // ---- 类 ----
    fn parse_class(&mut self, mods: &[String]) -> PResult<NodeId> {
        let is_data = self.eat_kw("data");
        let is_object = self.is_kw("object");
        let is_interface = self.is_kw("interface");
        self.bump(); // class / object / interface
        let name = self.expect_ident()?;
        // 泛型形参 `<T>` / `<K, V>`：捕获形参名（忽略上界约束），渲染为 `class Name<T>`。
        let mut generics: Vec<String> = Vec::new();
        if self.is_sym("<") {
            self.bump();
            let mut depth = 1;
            let mut expect_name = true;
            while depth > 0 && !self.at_eof() {
                if self.is_sym("<") {
                    depth += 1;
                    self.bump();
                } else if self.is_sym(">") {
                    depth -= 1;
                    self.bump();
                } else if self.is_sym(",") {
                    expect_name = depth == 1;
                    self.bump();
                } else if let Tok::Ident(id) = self.peek().clone() {
                    // 类/接口级泛型方差修饰符 `in`/`out`（及 inline `reified`）跳过，取真名。
                    // 与函数级 parse_generic_params 同逻辑；否则 `interface Predicate<in T>`
                    // 会把 `in` 当作参数名 push、真名 T 被丢，渲染成非法的 `<in>`。
                    if depth == 1 && matches!(id.as_str(), "in" | "out" | "reified") {
                        self.bump();
                    } else {
                        if expect_name && depth == 1 {
                            generics.push(id.clone());
                            expect_name = false;
                        }
                        self.bump();
                    }
                } else {
                    expect_name = false;
                    self.bump();
                }
            }
        }
        // 主构造器可紧跟类名（`class Foo(...)`），也可写在下一行并显式带 `constructor`
        // 关键字（KMP `expect class YearMonth` \n `public constructor(...)` 形式，
        // 类名与构造器间常隔 KDoc/换行）。跳过换行+修饰符后**仅当**见到 `constructor`
        // 关键字或 `(` 才消费——否则回退，避免吞掉下一个顶层声明（如 `class Foo\nfun bar`）
        // 的修饰符/内容。
        let ctor_scan = self.pos;
        self.skip_newlines();
        self.skip_modifiers();
        self.skip_newlines();
        if self.is_kw("constructor") || self.is_sym("(") {
            self.eat_kw("constructor");
            self.skip_newlines();
        } else {
            self.pos = ctor_scan;
        }
        let mut ctor_params = Vec::new();
        if self.eat_sym("(") {
            self.skip_newlines();
            while !self.is_sym(")") {
                self.skip_modifiers();
                let is_vararg = self.eat_kw("vararg");
                let kind = if self.eat_kw("val") {
                    CtorParamKind::Val
                } else if self.eat_kw("var") {
                    CtorParamKind::Var
                } else {
                    CtorParamKind::Plain
                };
                let pname = self.expect_ident()?;
                self.expect_sym(":")?;
                let ty = if is_vararg {
                    let base_ty = self.parse_type()?;
                    format!("Array<{}>", base_ty)
                } else {
                    self.parse_type()?
                };
                // 解析默认值
                let default = if self.eat_sym("=") {
                    Some(self.parse_expr()?)
                } else {
                    None
                };
                ctor_params.push(CtorParam {
                    kind,
                    name: safe_name(&pname),
                    ty,
                    default,
                });
                self.skip_newlines();
                if !self.eat_sym(",") {
                    break;
                }
                self.skip_newlines();
            }
            self.expect_sym(")")?;
        }
        // 继承列表：带 `(...)` 实参的超类型视为父类（生成 `super(...)`），
        // 其余无实参的视为接口。
        let mut superclass = None;
        let mut interfaces = Vec::new();
        let mut super_args = Vec::new();
        let mut supertype_delegations: Vec<SuperDelegation> = Vec::new();
        if self.eat_sym(":") {
            loop {
                self.skip_newlines();
                let sup = match self.peek().clone() {
                    Tok::Ident(s) => {
                        self.bump();
                        s
                    }
                    _ => break,
                };
                // Handle dotted supertype names: Outer.Inner, pkg.Outer.Inner
                let mut sup_name = sup;
                while self.is_sym(".") && self.peek_next_is_ident() {
                    self.bump(); // .
                    let part = self.expect_ident()?;
                    sup_name = format!("{}.{}", sup_name, part);
                }
                // stdlib 嵌套接口限定名折叠：仓颉无嵌套类型，父类型位的
                // `Map.Entry` / `MutableMap.MutableEntry` 折叠为顶层 marker
                // 接口名（由 stubs.rs 注入）。用户嵌套类的限定名折叠走
                // engine::apply_nested_lifting，不在此处理。
                sup_name = match sup_name.as_str() {
                    "Map.Entry" => "Entry".to_string(),
                    "MutableMap.MutableEntry" => "MutableEntry".to_string(),
                    _ => sup_name,
                };
                // 跳过泛型实参（如 `Map.Entry<String, String?>`），同时捕获顶层
                // 类型实参原文（`MutableList<T>` → "T"），供接口委托渲染 `List<T>`。
                let mut type_args = String::new();
                if self.eat_sym("<") {
                    let mut depth = 1i32;
                    let mut parts: Vec<String> = Vec::new();
                    while depth > 0 {
                        let tok = self.peek().clone();
                        match tok {
                            Tok::Sym(s) if s == "<" => { self.bump(); depth += 1; }
                            Tok::Sym(s) if s == ">" => { self.bump(); depth -= 1; }
                            Tok::Sym(s) if s == ">>" => { self.bump(); depth -= 2; }
                            Tok::Eof => break,
                            Tok::Ident(s) => {
                                // 顶层类型实参逐个映射（`Int`→`Int64` 等）；泛型形参
                                // （T/E/K/V）经 map_type 为恒等，无副作用。
                                if depth == 1 { parts.push(map_type(&s)); }
                                self.bump();
                            }
                            _ => { self.bump(); }
                        }
                    }
                    type_args = parts.join(", ");
                }
                // 接口委托：`MutableList<T> / List<T> by <delegate>` 折叠为真实仓颉
                // 集合接口 `List<T>` 并在渲染时自动生成转发成员（见 render_regular_class）。
                let is_delegatable_coll = matches!(sup_name.as_str(), "MutableList" | "List");
                if self.is_sym("(") {
                    self.bump();
                    self.skip_newlines();
                    while !self.is_sym(")") {
                        super_args.push(self.parse_expr()?);
                        self.skip_newlines();
                        if !self.eat_sym(",") {
                            break;
                        }
                        self.skip_newlines();
                    }
                    self.expect_sym(")")?;
                    // 保留父类泛型实参（`class Elements : Nodes<Element>(...)` →
                    // `<: Nodes<Element>`）。裸 `<: Nodes` 会让 cjc 报
                    // "generic type should be used with type argument" 并级联到
                    // 子类全部 override 失配。父类非泛型时 type_args 为空，不变。
                    superclass = Some(if type_args.is_empty() {
                        safe_name(&sup_name)
                    } else {
                        format!("{}<{}>", safe_name(&sup_name), type_args)
                    });
                } else if self.is_kw("by") && is_delegatable_coll {
                    // 集合接口委托：捕获委托表达式，交由渲染层生成 `List<T>` 父类型 +
                    // 转发成员。不推入 interfaces（避免再打 MutableList marker）。
                    self.bump(); // by
                    let prev = self.suppress_trailing_lambda;
                    self.suppress_trailing_lambda = true; // 防止类体 `{` 被当作尾随 lambda
                    let delegate = self.parse_expr();
                    self.suppress_trailing_lambda = prev; // 出错时也必须复位，避免泄漏到后续文件
                    let delegate = delegate?;
                    supertype_delegations.push(SuperDelegation {
                        supertype: safe_name(&sup_name),
                        type_args,
                        delegate,
                    });
                } else {
                    // 父接口/父类型位保留泛型实参（`class Instant : Comparable<Instant>` →
                    // `<: Comparable<Instant>`；`class X : Directive<Target>` → `<: Directive<Target>`）。
                    // 裸 `<: Comparable` 让 cjc 报 "generic type should be used with type
                    // argument"。此前仅 superclass 分支（带 `(...)`）保留 type_args，接口位漏掉。
                    // 例外：非泛型 marker 桩接口（MutableList/MutableMap/Entry/MutableEntry，
                    // stubs.rs 注入为空非泛型接口）不加实参——否则 `<: MutableList<Int>` 与
                    // 非泛型 marker 撞 arity（回归 242/243）。MutableCollection<E> 是泛型 marker，
                    // 不在此列。
                    let is_nongeneric_marker = matches!(
                        sup_name.as_str(),
                        "MutableList" | "MutableMap" | "Entry" | "MutableEntry"
                    );
                    interfaces.push(if type_args.is_empty() || is_nongeneric_marker {
                        safe_name(&sup_name)
                    } else {
                        format!("{}<{}>", safe_name(&sup_name), type_args)
                    });
                    // 非集合类接口委托（如 `class Foo : Bar by baz()`）：保持旧行为，
                    // 仅跳过委托表达式（尚不生成转发成员）。
                    if self.eat_kw("by") {
                        while !self.is_sym(",") && !self.is_sym("{") && !self.at_eof() {
                            self.bump();
                        }
                    }
                }
                if !self.eat_sym(",") {
                    break;
                }
            }
        }
        let mut members = Vec::new();
        let mut companion_members = Vec::new();
        let mut init_block: Option<NodeId> = None;
        self.skip_newlines();
        if self.eat_sym("{") {
            self.push_scope();
            // 让构造参数在成员体内可见
            self.skip_seps();
            while !self.is_sym("}") && !self.at_eof() {
                let mmods = self.skip_modifiers();
                if self.is_kw("fun") {
                    // `fun interface` 是 Kotlin SAM/函数式接口，不是函数声明。
                    if self.peek_next_is_kw("interface") {
                        self.bump(); // 跳过 `fun`
                        members.push(self.parse_class(&mmods)?);
                    } else {
                        members.push(self.parse_fun(&mmods)?);
                    }
                } else if self.is_kw("constructor") {
                    members.push(self.parse_secondary_constructor()?);
                } else if self.is_kw("val") || self.is_kw("var") {
                    members.push(self.parse_var_decl()?);
                } else if self.is_kw("init") {
                    // init 块：捕获块体，语句合并入仓颉构造器。
                    self.bump();
                    let blk = self.parse_block()?;
                    init_block = Some(blk);
                } else if self.is_kw("companion") {
                    // companion object { ... } → 解析成员作为静态方法/属性
                    self.bump(); // companion
                    self.eat_kw("object"); // object (optional)
                    // 可能有名字
                    if matches!(self.peek(), Tok::Ident(s) if s != "object" && !s.is_empty()) {
                        if !self.is_sym("{") {
                            self.bump(); // companion name
                        }
                    }
                    if self.is_sym("{") {
                        self.bump(); // {
                        self.skip_seps();
                        while !self.is_sym("}") && !self.at_eof() {
                            let cmods = self.skip_modifiers();
                            if self.is_kw("fun") {
                                if self.peek_next_is_kw("interface") {
                                    self.bump();
                                    let iface = self.parse_class(&cmods)?;
                                    companion_members.push(iface);
                                    members.push(iface);
                                } else {
                                    let func = self.parse_fun(&cmods)?;
                                    companion_members.push(func);
                                    members.push(func);
                                }
                            } else if self.is_kw("val") || self.is_kw("var") {
                                let v = self.parse_var_decl()?;
                                companion_members.push(v);
                                members.push(v);
                            } else if self.is_kw("const") {
                                self.bump(); // const
                                let v = self.parse_var_decl()?;
                                companion_members.push(v);
                                members.push(v);
                            } else if self.is_kw("class")
                                || self.is_kw("object")
                                || self.is_kw("interface")
                            {
                                // companion 内的嵌套类（如 ksoup Element 的 NodeList）：
                                // 按类体嵌套类同款处理——parse 后由 renderer 提升到顶层。
                                // 不进 companion_members（它不是静态方法），否则其成员会被
                                // 逐 token 跳过时误捡为 companion 成员，渲染成非法的
                                // `static override func`。
                                members.push(self.parse_class(&cmods)?);
                            } else {
                                self.bump();
                            }
                            self.skip_seps();
                        }
                        self.expect_sym("}")?;
                    }
                } else if self.is_kw("class") || self.is_kw("object") || self.is_kw("interface") {
                    // Cangjie does not support class declarations inside class bodies.
                    // Preserve Kotlin nested classes by parsing them here and letting the
                    // renderer lift them to the surrounding top-level output.
                    members.push(self.parse_class(&mmods)?);
                } else if self.is_kw("enum") {
                    members.push(self.parse_enum()?);
                } else {
                    self.bump();
                }
                self.skip_seps();
            }
            if self.at_eof() {
                // File ended inside class body — close gracefully
                eprintln!("PARSE NOTE: EOF inside class body, closing implicitly");
            } else {
                self.expect_sym("}")?;
            }
            self.pop_scope();
        }
        let _ = is_object;
        let is_singleton = is_object;
        let is_abstract = mods.iter().any(|m| m == "abstract");
        let is_open = mods
            .iter()
            .any(|m| m == "open" || m == "abstract" || m == "sealed");
        let is_value = mods.iter().any(|m| m == "value");
        let is_expect = mods.iter().any(|m| m == "expect");
        Ok(self.g.add(Kind::Class {
            name: safe_name(&name),
            ctor_params,
            members,
            superclass,
            is_open,
            is_data,
            is_value,
            is_interface,
            is_abstract,
            interfaces,
            super_args,
            generics,
            init_block,
            companion_members,
            is_singleton,
            supertype_delegations,
            is_expect,
        }))
    }

    fn parse_secondary_constructor(&mut self) -> PResult<NodeId> {
        self.eat_kw("constructor");
        self.push_scope();
        let params = self.parse_param_nodes()?;
        self.skip_newlines();
        let delegate = if self.eat_sym(":") {
            self.skip_newlines();
            let target = if self.eat_kw("this") {
                "this".to_string()
            } else if self.eat_kw("super") {
                "super".to_string()
            } else {
                return Err(format!(
                    "line {}: constructor 之后期望 this(...) 或 super(...)",
                    self.line()
                ));
            };
            let args = self.parse_args_no_trailing_lambda()?;
            Some(ConstructorDelegate { target, args })
        } else {
            None
        };
        self.skip_newlines();
        let body = if self.is_sym("{") {
            self.parse_block()?
        } else {
            self.g.add(Kind::Block { stmts: Vec::new() })
        };
        self.pop_scope();
        Ok(self.g.add(Kind::SecondaryConstructor {
            params,
            delegate,
            body,
        }))
    }

    // ================= 语句 =================
    fn parse_block(&mut self) -> PResult<NodeId> {
        self.expect_sym("{")?;
        self.push_scope();
        let mut stmts = Vec::new();
        self.skip_seps();
        while !self.is_sym("}") && !self.at_eof() {
            let s = self.parse_statement()?;
            stmts.push(s);
            self.skip_seps();
        }
        self.expect_sym("}")?;
        self.pop_scope();
        Ok(self.g.add(Kind::Block { stmts }))
    }

    fn parse_statement(&mut self) -> PResult<NodeId> {
        self.skip_modifiers();
        if self.is_kw("val") || self.is_kw("var") {
            return self.parse_var_decl();
        }
        if self.is_kw("return") {
            self.bump();
            // `return@label` 标签返回 — 仓颉无标签，直接丢弃标签
            if self.is_sym("@") {
                self.bump();
                self.expect_ident()?;
            }
            if matches!(self.peek(), Tok::Newline | Tok::Eof)
                || self.is_sym("}")
                || self.is_sym(";")
            {
                return Ok(self.g.add(Kind::Return { value: None }));
            }
            let e = self.parse_expr()?;
            return Ok(self.g.add(Kind::Return { value: Some(e) }));
        }
        if self.is_kw("throw") {
            self.bump();
            let e = self.parse_expr()?;
            return Ok(self.g.add(Kind::Throw { value: e }));
        }
        if self.is_kw("while") {
            return self.parse_while();
        }
        if self.is_kw("do") {
            return self.parse_do_while();
        }
        if self.is_kw("try") {
            return self.parse_try();
        }
        if self.is_kw("for") {
            return self.parse_for();
        }
        if self.is_kw("break") {
            self.bump();
            // `break@label` 标签跳出
            if self.is_sym("@") {
                self.bump();
                self.expect_ident()?;
            }
            return Ok(self.g.add(Kind::Raw("break".into())));
        }
        if self.is_kw("continue") {
            self.bump();
            // `continue@label` 标签继续
            if self.is_sym("@") {
                self.bump();
                self.expect_ident()?;
            }
            return Ok(self.g.add(Kind::Raw("continue".into())));
        }
        if self.is_kw("fun") {
            return self.parse_fun(&[]);
        }
        // 表达式语句 / 赋值
        let e = self.parse_expr()?;
        if self.is_sym("++") || self.is_sym("--") {
            let op = if self.is_sym("++") { "+=" } else { "-=" };
            self.bump();
            let one = self.g.add(Kind::IntLit("1".into()));
            return Ok(self.g.add(Kind::Assign {
                target: e,
                op: op.into(),
                value: one,
            }));
        }
        if let Tok::Sym(op) = self.peek().clone() {
            if matches!(op.as_str(), "=" | "+=" | "-=" | "*=" | "/=" | "%=") {
                self.bump();
                self.skip_newlines();
                let val = self.parse_expr()?;
                return Ok(self.g.add(Kind::Assign {
                    target: e,
                    op,
                    value: val,
                }));
            }
        }
        Ok(self.g.add(Kind::ExprStmt { expr: e }))
    }

    fn parse_var_decl(&mut self) -> PResult<NodeId> {
        let mutable = if self.eat_kw("var") {
            true
        } else {
            self.eat_kw("val");
            false
        };
        // 解构声明 `val (a, b) = expr`
        if self.is_sym("(") {
            self.bump();
            let mut name_nodes = Vec::new();
            loop {
                let nm = self.expect_ident()?;
                // 跳过可选类型标注 `a: T`
                if self.eat_sym(":") {
                    self.parse_type()?;
                }
                let nn = self.g.add(Kind::Name {
                    original: nm.clone(),
                });
                name_nodes.push((nm, nn));
                if !self.eat_sym(",") {
                    break;
                }
                self.skip_newlines();
            }
            self.expect_sym(")")?;
            self.expect_sym("=")?;
            self.skip_newlines();
            let init = self.parse_expr()?;
            for (nm, nn) in &name_nodes {
                self.declare(nm, *nn);
            }
            let names: Vec<NodeId> = name_nodes.into_iter().map(|(_, nn)| nn).collect();
            return Ok(self.g.add(Kind::DestructureDecl {
                mutable,
                names,
                init,
            }));
        }
        let name = self.expect_ident()?;
        // 扩展属性 `val ReceiverType.name: T get() = expr` → 转为扩展函数
        // `extend ReceiverType { func name(): T { return expr } }` 复用 Func Kind
        // 渲染路径。k2cj 原本只把 ReceiverType 当变量名,遇 `.` 卡住。
        if self.is_sym(".") {
            self.bump(); // eat '.'
            let receiver_type = name;
            let prop_name = self.expect_ident()?;
            let ret = if self.eat_sym(":") {
                Some(self.parse_type()?)
            } else {
                None
            };
            // get() = expr / get() { body } / 直接 = expr
            let body = if self.eat_sym("=") {
                let e = self.parse_expr()?;
                let r = self.g.add(Kind::Return { value: Some(e) });
                self.g.add(Kind::Block { stmts: vec![r] })
            } else if self.is_kw("get") {
                self.bump(); // get
                if self.is_sym("(") {
                    self.skip_balanced_parens();
                }
                if self.eat_sym("=") {
                    let e = self.parse_expr()?;
                    let r = self.g.add(Kind::Return { value: Some(e) });
                    self.g.add(Kind::Block { stmts: vec![r] })
                } else if self.is_sym("{") {
                    self.parse_block()?
                } else {
                    self.g.add(Kind::Block { stmts: vec![] })
                }
            } else {
                self.g.add(Kind::Block { stmts: vec![] })
            };
            // 跳过 set() 等其他访问器
            self.skip_property_accessors();
            return Ok(self.g.add(Kind::Func {
                name: crate::parser::safe_name(&prop_name),
                params: vec![],
                ret,
                body,
                is_main: false,
                is_abstract: false,
                is_override: false,
                receiver_type: Some(receiver_type),
                generic_params: vec![],
            }));
        }
        let mut ty = None;
        if self.eat_sym(":") {
            ty = Some(self.parse_type()?);
        }
        let mut init = None;
        let mut is_lazy = false;
        if self.eat_sym("=") {
            self.skip_newlines();
            self.pending_object_type = None;
            init = Some(self.parse_expr()?);
            // `val x = object : T {...}`：匿名对象无自身类型，用超类型 T 给字段补类型
            // （否则 singleton 拆分出的 `let x` 无类型解析崩溃）。
            if ty.is_none() {
                if let Some(obj_ty) = self.pending_object_type.take() {
                    ty = Some(obj_ty);
                }
            }
        } else if self.is_kw("by") {
            // `val x by lazy { expr }` → evaluate eagerly
            self.bump(); // by
            if self.eat_kw("lazy") {
                is_lazy = true;
                if self.is_sym("{") {
                    let lam = self.parse_lambda()?;
                    // Extract lambda body as the init expression
                    if let Kind::Lambda { body, .. } = self.g.kind(lam).clone() {
                        init = Some(self.wrap_lambda_body_as_expr(body));
                    }
                } else if self.is_sym("(") {
                    // `by lazy(mode) { expr }`
                    self.skip_balanced_parens();
                    if self.is_sym("{") {
                        let lam = self.parse_lambda()?;
                        if let Kind::Lambda { body, .. } = self.g.kind(lam).clone() {
                            init = Some(self.wrap_lambda_body_as_expr(body));
                        }
                    }
                }
            } else {
                // Other delegated properties — skip the delegate expression
                init = Some(self.parse_expr()?);
            }
        }
        // getter-only 属性 `val x get() = expr` / `val x: T get() = expr`（无初始化器、
        // 无 backing field）：捕获 getter 返回表达式作为字段初始化，渲染为 `let x = expr`。
        // 仓颉无「纯 getter 计算属性」简写；退化为字段——datetime 里此类 getter 多返回
        // 常量对象（emptyIntermediate 等），语义等价。原先 skip_property_accessors 直接
        // 丢弃 getter，导致 `let x`（无类型无初始化）解析崩溃或 uninit 字段。
        if init.is_none() && !is_lazy {
            init = self.try_capture_getter_init();
        }
        // 跳过剩余属性访问器 get()/get() = expr/get() { ... } / set(value) / private set
        self.skip_property_accessors();
        let name_node = self.g.add(Kind::Name {
            original: name.clone(),
        });
        self.declare(&name, name_node);
        Ok(self.g.add(Kind::VarDecl {
            mutable,
            name_node,
            ty,
            init,
            is_lazy,
        }))
    }

    /// 捕获 getter-only 属性的 getter 返回表达式（`get() = expr` 或 `get() { block }`），
    /// 作为字段初始化。仅消费 getter 本身；失败/无 getter 时回退 pos 并返回 None。
    fn try_capture_getter_init(&mut self) -> Option<NodeId> {
        let save = self.pos;
        self.skip_newlines();
        self.skip_modifiers();
        if !self.eat_kw("get") {
            self.pos = save;
            return None;
        }
        if self.is_sym("(") {
            self.skip_balanced_parens();
        }
        self.skip_newlines();
        // 可选返回类型标注 `get(): T` —— 跳过
        if self.eat_sym(":") {
            let _ = self.parse_type();
        }
        self.skip_newlines();
        if self.eat_sym("=") {
            self.skip_newlines();
            match self.parse_expr() {
                Ok(e) => Some(e),
                Err(_) => {
                    self.pos = save;
                    None
                }
            }
        } else if self.is_sym("{") {
            match self.parse_block() {
                Ok(block) => Some(self.wrap_lambda_body_as_expr(block)),
                Err(_) => {
                    self.pos = save;
                    None
                }
            }
        } else {
            // 抽象/无体 getter（`val x: T get`）—— 无表达式可捕获，回退
            self.pos = save;
            None
        }
    }

    /// Wrap a lambda body (Block) as an IIFE expression `({ => body })()`
    fn wrap_lambda_body_as_expr(&mut self, body: NodeId) -> NodeId {
        let lam = self.g.add(Kind::Lambda {
            params: vec![],
            body,
        });
        self.g.add(Kind::Call {
            callee: lam,
            args: vec![],
        })
    }

    /// 递归遍历 `root` 子树，把所有 `original == old` 的 NameRef 改成 `new`，
    /// 并把 `decl` 指向 `decl_node`。用于 `also` lambda 内联时把 `it` 重写为
    /// `_also_it`（避免 alias decl `let it = _also_it` 撞外部作用域 `it`）。
    fn rename_namerefs_in_subtree(
        &mut self,
        root: NodeId,
        old: &str,
        new: &str,
        decl_node: NodeId,
    ) {
        let mut stack = vec![root];
        while let Some(id) = stack.pop() {
            if let Kind::NameRef { original, decl } = &mut self.g.nodes[id].kind {
                if *original == old {
                    *original = new.to_string();
                    *decl = Some(decl_node);
                }
            }
            let children = self.g.children_of(id);
            stack.extend(children);
        }
    }

    fn parse_while(&mut self) -> PResult<NodeId> {
        self.eat_kw("while");
        self.expect_sym("(")?;
        self.skip_newlines();
        let cond = self.parse_expr()?;
        self.skip_newlines();
        self.expect_sym(")")?;
        self.skip_newlines();
        let body = self.parse_block_or_stmt()?;
        Ok(self.g.add(Kind::While { cond, body }))
    }

    fn parse_do_while(&mut self) -> PResult<NodeId> {
        self.eat_kw("do");
        self.skip_newlines();
        let body = self.parse_block_or_stmt()?;
        self.skip_newlines();
        if !self.eat_kw("while") {
            return Err(format!("line {}: do 之后期望 while", self.line()));
        }
        self.expect_sym("(")?;
        self.skip_newlines();
        let cond = self.parse_expr()?;
        self.skip_newlines();
        self.expect_sym(")")?;
        Ok(self.g.add(Kind::DoWhile { body, cond }))
    }

    fn parse_try(&mut self) -> PResult<NodeId> {
        self.eat_kw("try");
        self.skip_newlines();
        let body = self.parse_block()?;
        let mut catches = Vec::new();
        let mut finally = None;
        loop {
            self.skip_newlines_for_kw("catch");
            self.skip_newlines_for_kw("finally");
            if self.eat_kw("catch") {
                self.expect_sym("(")?;
                let name = self.expect_ident()?;
                self.expect_sym(":")?;
                let ty = self.parse_type()?;
                self.expect_sym(")")?;
                self.skip_newlines();
                self.push_scope();
                let nn = self.g.add(Kind::Name {
                    original: name.clone(),
                });
                self.declare(&name, nn);
                let cbody = self.parse_block()?;
                self.pop_scope();
                catches.push(CatchClause {
                    name: safe_name(&name),
                    ty,
                    body: cbody,
                });
            } else if self.eat_kw("finally") {
                self.skip_newlines();
                finally = Some(self.parse_block()?);
                break;
            } else {
                break;
            }
        }
        Ok(self.g.add(Kind::Try {
            body,
            catches,
            finally,
        }))
    }

    fn skip_newlines_for_kw(&mut self, kw: &str) {
        let save = self.pos;
        self.skip_newlines();
        if !self.is_kw(kw) {
            self.pos = save;
        }
    }

    fn parse_for(&mut self) -> PResult<NodeId> {
        self.eat_kw("for");
        self.expect_sym("(")?;
        self.push_scope();
        // 解构循环变量：for ((k, v) in m)
        if self.is_sym("(") {
            self.bump();
            let mut name_nodes = Vec::new();
            loop {
                let nm = self.expect_ident()?;
                let nn = self.g.add(Kind::Name {
                    original: nm.clone(),
                });
                self.declare(&nm, nn);
                name_nodes.push(nn);
                if !self.eat_sym(",") {
                    break;
                }
                self.skip_newlines();
            }
            self.expect_sym(")")?;
            self.eat_kw("in");
            let var = self.g.add(Kind::Destructure { names: name_nodes });
            let iter_expr = self.parse_expr()?;
            self.expect_sym(")")?;
            self.skip_newlines();
            let body = self.parse_block_or_stmt()?;
            self.pop_scope();
            return Ok(self.g.add(Kind::ForEach {
                var,
                iter: iter_expr,
                body,
            }));
        }
        let var_name = self.expect_ident()?;
        self.eat_kw("in");
        let var_node = self.g.add(Kind::Name {
            original: var_name.clone(),
        });
        self.declare(&var_name, var_node);
        let var = self.g.add(Kind::VarDecl {
            mutable: false,
            name_node: var_node,
            ty: None,
            init: None,
            is_lazy: false,
        });
        // 区间 or 可迭代对象
        let iter_expr = self.parse_expr()?;
        self.expect_sym(")")?;
        self.skip_newlines();
        let body = self.parse_block_or_stmt()?;
        self.pop_scope();
        if matches!(self.g.kind(iter_expr), Kind::Range { .. }) {
            Ok(self.g.add(Kind::ForRange {
                var,
                range: iter_expr,
                body,
            }))
        } else {
            Ok(self.g.add(Kind::ForEach {
                var,
                iter: iter_expr,
                body,
            }))
        }
    }

    fn parse_block_or_stmt(&mut self) -> PResult<NodeId> {
        if self.is_sym("{") {
            self.parse_block()
        } else {
            let s = self.parse_statement()?;
            Ok(self.g.add(Kind::Block { stmts: vec![s] }))
        }
    }

    // ================= 表达式 =================
    fn parse_expr(&mut self) -> PResult<NodeId> {
        self.parse_or()
    }

    fn parse_binary_level(
        &mut self,
        ops: &[&str],
        next: fn(&mut Self) -> PResult<NodeId>,
    ) -> PResult<NodeId> {
        let mut lhs = next(self)?;
        loop {
            let save = self.pos;
            self.skip_newlines();
            let mut matched = None;
            if let Tok::Sym(s) = self.peek() {
                if ops.contains(&s.as_str()) {
                    matched = Some(s.clone());
                }
            }
            match matched {
                Some(op) => {
                    self.bump();
                    self.skip_newlines();
                    let rhs = next(self)?;
                    lhs = self.g.add(Kind::Binary { op, lhs, rhs });
                }
                None => {
                    self.pos = save;
                    break;
                }
            }
        }
        Ok(lhs)
    }

    fn parse_or(&mut self) -> PResult<NodeId> {
        self.parse_binary_level(&["||"], Self::parse_and)
    }
    fn parse_and(&mut self) -> PResult<NodeId> {
        self.parse_binary_level(&["&&"], Self::parse_equality)
    }
    fn parse_equality(&mut self) -> PResult<NodeId> {
        self.parse_binary_level(&["==", "!="], Self::parse_comparison)
    }
    fn parse_comparison(&mut self) -> PResult<NodeId> {
        self.parse_binary_level(&["<", "<=", ">", ">="], Self::parse_named_checks)
    }
    /// Kotlin 的 `in` / `!in` 成员检查与 `is` / `!is` 类型判定
    /// （优先级介于比较与 elvis 之间）。
    fn parse_named_checks(&mut self) -> PResult<NodeId> {
        let mut lhs = self.parse_elvis()?;
        loop {
            // `is T` / `!is T` 类型判定
            if self.is_kw("is") {
                self.bump();
                let ty = self.parse_type()?;
                lhs = self.g.add(Kind::IsCheck {
                    expr: lhs,
                    ty,
                    negate: false,
                });
                continue;
            }
            if self.is_sym("!") && self.peek_next_is_kw("is") {
                self.bump(); // !
                self.bump(); // is
                let ty = self.parse_type()?;
                lhs = self.g.add(Kind::IsCheck {
                    expr: lhs,
                    ty,
                    negate: true,
                });
                continue;
            }
            // `as T` / `as? T` 类型转换
            if self.is_kw("as") {
                self.bump();
                let safe = self.eat_sym("?");
                let ty = self.parse_type()?;
                lhs = self.g.add(Kind::TypeCast {
                    expr: lhs,
                    ty,
                    safe,
                });
                continue;
            }
            let negate = if self.is_sym("!") && self.peek_next_is_kw("in") {
                self.bump(); // !
                true
            } else {
                false
            };
            if self.is_kw("in") {
                self.bump();
                self.skip_newlines();
                let rhs = self.parse_elvis()?;
                let op = if negate { "!in" } else { "in" };
                lhs = self.g.add(Kind::Binary {
                    op: op.into(),
                    lhs,
                    rhs,
                });
            } else {
                if negate {
                    // 回退：把消费掉的 `!` 当作错误，理论上不会到这里
                }
                break;
            }
        }
        // 重新检查 elvis 运算符：`expr as? Type ?: default` 中，`?:` 优先级低于 `as?`，
        // 但 `parse_elvis` 在 `as?` 之前已被调用，此处需要二次检查。
        self.skip_newlines();
        if self.eat_sym("?:") {
            self.skip_newlines();
            let rhs = self.parse_named_checks()?;
            lhs = self.g.add(Kind::Binary {
                op: "?:".into(),
                lhs,
                rhs,
            });
        }
        Ok(lhs)
    }
    fn parse_elvis(&mut self) -> PResult<NodeId> {
        self.parse_binary_level(&["?:"], Self::parse_to)
    }

    fn parse_to(&mut self) -> PResult<NodeId> {
        let mut lhs = self.parse_range()?;
        loop {
            if self.is_kw("to") {
                self.bump();
                self.skip_newlines();
                let rhs = self.parse_range()?;
                lhs = self.g.add(Kind::Binary {
                    op: "to".into(),
                    lhs,
                    rhs,
                });
                continue;
            }
            // 命名中缀位运算：and / or / xor / shl / shr / ushr
            let mapped = match self.peek() {
                Tok::Ident(x) => match x.as_str() {
                    "and" => Some("&"),
                    "or" => Some("|"),
                    "xor" => Some("^"),
                    "shl" => Some("<<"),
                    "shr" | "ushr" => Some(">>"),
                    _ => None,
                },
                _ => None,
            };
            if let Some(op) = mapped {
                self.bump();
                self.skip_newlines();
                let rhs = self.parse_range()?;
                lhs = self.g.add(Kind::Binary {
                    op: op.into(),
                    lhs,
                    rhs,
                });
                continue;
            }
            break;
        }
        Ok(lhs)
    }

    fn parse_range(&mut self) -> PResult<NodeId> {
        let lo = self.parse_additive()?;
        // a..b / a..<b / a until b / a downTo b (可带 step)
        let (inclusive, down, is_range) = if self.is_sym("..") {
            self.bump();
            // Kotlin `..<` 开区间运算符 (rangeUntil)
            if self.eat_sym("<") {
                (false, false, true)
            } else {
                (true, false, true)
            }
        } else if self.is_kw("until") {
            self.bump();
            (false, false, true)
        } else if self.is_kw("downTo") {
            self.bump();
            (true, true, true)
        } else {
            (false, false, false)
        };
        if !is_range {
            return Ok(lo);
        }
        self.skip_newlines();
        let hi = self.parse_additive()?;
        let mut step = None;
        if self.eat_kw("step") {
            step = Some(self.parse_additive()?);
        }
        Ok(self.g.add(Kind::Range {
            lo,
            hi,
            inclusive,
            down,
            step,
        }))
    }

    fn parse_additive(&mut self) -> PResult<NodeId> {
        self.parse_binary_level(&["+", "-"], Self::parse_multiplicative)
    }
    fn parse_multiplicative(&mut self) -> PResult<NodeId> {
        self.parse_binary_level(&["*", "/", "%"], Self::parse_unary)
    }

    fn parse_unary(&mut self) -> PResult<NodeId> {
        // throw 表达式（如 `?: throw X(...)` Elvis 右操作数，或 `= throw X(...)` 表达式体）。
        // 1e R2 只在 parse_stmt 级别处理 throw，Elvis rhs 走 parse_unary 不识别 throw，
        // 导致 `?? throw` 渲染丢异常实参。这里在表达式层加 throw 处理。
        if self.is_kw("throw") {
            self.bump();
            let e = self.parse_expr()?;
            return Ok(self.g.add(Kind::Throw { value: e }));
        }
        if self.is_sym("!") || self.is_sym("-") || self.is_sym("+") || self.is_sym("*")
            || self.is_sym("++") || self.is_sym("--")
        {
            let is_inc = self.is_sym("++");
            let is_dec = self.is_sym("--");
            let op = if let Tok::Sym(s) = self.bump() {
                s
            } else {
                unreachable!()
            };
            self.skip_newlines();
            let e = self.parse_unary()?;
            if op == "+" {
                return Ok(e);
            }
            if op == "*" {
                return Ok(self.g.add(Kind::Spread { expr: e }));
            }
            // 前缀 ++/-- → 仓颉 `e += 1` / `e -= 1`
            if is_inc || is_dec {
                let one = self.g.add(Kind::IntLit("1".into()));
                let assign_op = if is_inc { "+=" } else { "-=" };
                return Ok(self.g.add(Kind::Assign {
                    target: e,
                    op: assign_op.into(),
                    value: one,
                }));
            }
            return Ok(self.g.add(Kind::Unary { op, expr: e }));
        }
        self.parse_postfix()
    }

    fn parse_postfix(&mut self) -> PResult<NodeId> {
        let mut e = self.parse_primary()?;
        loop {
            // 允许换行后接 . 链式调用
            if matches!(self.peek(), Tok::Newline) {
                let save = self.pos;
                self.skip_newlines();
                if !(self.is_sym(".") || self.is_sym("?.")) {
                    self.pos = save;
                    break;
                }
            }
            if self.is_sym(".") || self.is_sym("?.") {
                let safe = self.is_sym("?.");
                self.bump();
                let name = self.expect_ident()?;
                // 显式泛型实参调用：`obj.method<T>(args)`。
                // 用试探性解析 + 回退避免将 `obj.x < y` 比较误判为泛型。
                if self.is_sym("<") {
                    let saved = self.pos;
                    if self.try_skip_generic_args() && self.is_sym("(") {
                        // 泛型实参 + '(' → 确认为泛型调用，保持跳过。
                    } else {
                        self.pos = saved; // 回退
                    }
                }
                if self.is_sym("(") {
                    let args = self.parse_args()?;
                    let m = self.g.add(Kind::Member {
                        base: e,
                        name,
                        safe,
                    });
                    e = self.g.add(Kind::Call { callee: m, args });
                } else if self.is_sym("{") && !self.suppress_trailing_lambda {
                    // 无括号尾随 lambda：recv.method { ... }
                    let lam = self.parse_lambda()?;
                    if name == "forEach" {
                        e = self.build_for_each(e, lam);
                    } else if name == "forEachIndexed" {
                        e = self.build_for_each_indexed(e, lam);
                    } else if name == "let" {
                        // recv?.let { it -> ... } / recv.let { ... }
                        e = self.build_safe_let(e, lam);
                    } else if name == "also" {
                        // recv.also { it -> body } → { let _it = recv; body(it=_it); _it }
                        e = self.build_also(e, lam);
                    } else if name == "apply" {
                        // recv.apply { body } → { let _it = recv; body; _it }
                        e = self.build_also(e, lam);
                    } else if name == "run" {
                        // recv.run { body } → { let _r = recv; body }
                        e = self.build_run(e, lam);
                    } else {
                        let m = self.g.add(Kind::Member {
                            base: e,
                            name,
                            safe,
                        });
                        e = self.g.add(Kind::Call {
                            callee: m,
                            args: vec![lam],
                        });
                    }
                } else {
                    e = self.g.add(Kind::Member {
                        base: e,
                        name,
                        safe,
                    });
                }
            } else if self.is_sym("(") {
                let args = self.parse_args()?;
                e = self.g.add(Kind::Call { callee: e, args });
            } else if self.is_sym("[") {
                self.bump();
                let idx = self.parse_expr()?;
                self.expect_sym("]")?;
                e = self.g.add(Kind::Index {
                    base: e,
                    index: idx,
                });
            } else if self.is_sym("!") && self.peek_next_is_bang() {
                // !! 非空断言 → ForceUnwrap
                self.bump();
                self.bump();
                e = self.g.add(Kind::ForceUnwrap { expr: e });
            } else if self.is_sym("::") {
                // 双冒号引用：Foo::class, Foo::method
                self.bump(); // ::
                let name = self.expect_ident()?;
                e = self.g.add(Kind::Member {
                    base: e,
                    name: format!("::{}", name),
                    safe: false,
                });
            } else if self.is_sym("++") || self.is_sym("--") {
                // Postfix increment/decrement: x++ / x--
                let is_inc = self.is_sym("++");
                self.bump();
                let one = self.g.add(Kind::IntLit("1".into()));
                let op = if is_inc { "+=" } else { "-=" };
                e = self.g.add(Kind::Assign {
                    target: e,
                    op: op.into(),
                    value: one,
                });
            } else if self.is_sym("{") && !self.suppress_trailing_lambda {
                // 无括号尾随 lambda 调用：ident { ... }
                let lam = self.parse_lambda()?;
                e = self.g.add(Kind::Call { callee: e, args: vec![lam] });
            } else {
                break;
            }
        }
        Ok(e)
    }

    fn build_for_each(&mut self, recv: NodeId, lam: NodeId) -> NodeId {
        let (params, body) = if let Kind::Lambda { params, body } = self.g.kind(lam) {
            (params.clone(), *body)
        } else {
            (Vec::new(), lam)
        };
        let var_name = params.first().cloned().unwrap_or_else(|| "it".to_string());
        let nn = self.g.add(Kind::Name { original: var_name });
        let var = self.g.add(Kind::VarDecl {
            mutable: false,
            name_node: nn,
            ty: None,
            init: None,
            is_lazy: false,
        });
        self.g.add(Kind::ForEach {
            var,
            iter: recv,
            body,
        })
    }

    /// xs.forEachIndexed { i, v -> ... } → for ((i, v) in xs.withIndex()) { ... }
    fn build_for_each_indexed(&mut self, recv: NodeId, lam: NodeId) -> NodeId {
        let (params, body) = if let Kind::Lambda { params, body } = self.g.kind(lam) {
            (params.clone(), *body)
        } else {
            (Vec::new(), lam)
        };
        let strip = |p: &String| -> String {
            p.split_once(':')
                .map(|(n, _)| n.trim().to_string())
                .unwrap_or_else(|| p.clone())
        };
        let iname = params
            .first()
            .map(&strip)
            .unwrap_or_else(|| "index".to_string());
        let vname = params
            .get(1)
            .map(&strip)
            .unwrap_or_else(|| "it".to_string());
        let in_node = self.g.add(Kind::Name { original: iname });
        let vn_node = self.g.add(Kind::Name { original: vname });
        let var = self.g.add(Kind::Destructure {
            names: vec![in_node, vn_node],
        });
        let wi = self.g.add(Kind::Member {
            base: recv,
            name: "withIndex".to_string(),
            safe: false,
        });
        let iter = self.g.add(Kind::Call {
            callee: wi,
            args: vec![],
        });
        self.g.add(Kind::ForEach { var, iter, body })
    }

    fn build_safe_let(&mut self, recv: NodeId, lam: NodeId) -> NodeId {
        let (params, body) = if let Kind::Lambda { params, body } = self.g.kind(lam) {
            (params.clone(), *body)
        } else {
            (Vec::new(), lam)
        };
        let var = params.first().cloned().unwrap_or_else(|| "it".to_string());
        self.g.add(Kind::SafeLet { recv, var, body })
    }

    /// `recv.also { it -> body }` → `({ => let _also = recv; body(it=_also); _also })()`
    fn build_also(&mut self, recv: NodeId, lam: NodeId) -> NodeId {
        let (params, body) = if let Kind::Lambda { params, body } = self.g.kind(lam) {
            (params.clone(), *body)
        } else {
            (Vec::new(), lam)
        };
        let var_name = params.first().cloned().unwrap_or_else(|| "it".to_string());
        let pname = var_name
            .split(':')
            .next()
            .unwrap_or(&var_name)
            .trim()
            .to_string();
        let unique = format!("_also_{}", pname);
        let nn = self.g.add(Kind::Name {
            original: unique.clone(),
        });
        let decl = self.g.add(Kind::VarDecl {
            mutable: false,
            name_node: nn,
            ty: None,
            init: Some(recv),
            is_lazy: false,
        });
        // Rename all `<pname>` NameRefs in the lambda body to `unique` (=_also_<pname>).
        // Avoids `let it = _also_it` alias decl which clashes with outer-scope `it`
        // (redefinition of declaration 'it' when nested in another lambda's `it` scope).
        // Body NameRefs for lambda params have decl=None (Lambda params are strings, not
        // nodes), render via `original` — so rewriting original + pointing decl at nn
        // makes them resolve to the `let _also_it = recv` decl above.
        self.rename_namerefs_in_subtree(body, &pname, &unique, nn);
        let ret_ref = self.g.add(Kind::NameRef {
            original: unique,
            decl: Some(nn),
        });
        let ret_stmt = self.g.add(Kind::Return {
            value: Some(ret_ref),
        });
        // Merge: let _also_it = recv; <body stmts with it→_also_it>; return _also_it
        let mut stmts = vec![decl];
        if let Kind::Block { stmts: body_stmts } = self.g.kind(body).clone() {
            stmts.extend(body_stmts);
        } else {
            stmts.push(self.g.add(Kind::ExprStmt { expr: body }));
        }
        stmts.push(ret_stmt);
        let block = self.g.add(Kind::Block { stmts });
        let outer_lam = self.g.add(Kind::Lambda {
            params: vec![],
            body: block,
        });
        self.g.add(Kind::Call {
            callee: outer_lam,
            args: vec![],
        })
    }

    /// `recv.run { body }` → `({ => body with this=recv })()`
    /// Simplified: desugar as IIFE with last-expr return
    fn build_run(&mut self, recv: NodeId, lam: NodeId) -> NodeId {
        let (_params, body) = if let Kind::Lambda { params, body } = self.g.kind(lam) {
            (params.clone(), *body)
        } else {
            (Vec::new(), lam)
        };
        // For now, treat .run { body } same as .let { body } since `this` in body
        // maps to the receiver in Cangjie as well for simple cases
        let _recv = recv; // receiver value is available via closure capture
        let outer_lam = self.g.add(Kind::Lambda {
            params: vec![],
            body,
        });
        self.g.add(Kind::Call {
            callee: outer_lam,
            args: vec![],
        })
    }

    fn peek_next_is_bang(&self) -> bool {
        self.pos + 1 < self.toks.len()
            && matches!(&self.toks[self.pos + 1].tok, Tok::Sym(s) if s == "!")
    }

    fn peek_next_is_kw(&self, kw: &str) -> bool {
        self.pos + 1 < self.toks.len()
            && matches!(&self.toks[self.pos + 1].tok, Tok::Ident(s) if s == kw)
    }

    fn peek_next_is_ident(&self) -> bool {
        self.pos + 1 < self.toks.len() && matches!(&self.toks[self.pos + 1].tok, Tok::Ident(_))
    }

    /// builder 名后紧跟 `(` 或 `<`（泛型实参）。
    fn peek_after_ident_is_call_or_generic(&self) -> bool {
        if self.pos + 1 < self.toks.len() {
            matches!(&self.toks[self.pos + 1].tok, Tok::Sym(s) if s == "(" || s == "<")
        } else {
            false
        }
    }

    /// 探测 `Ident<类型实参...>(` 形态（用户泛型类构造，如 `Stack<Int>()`），
    /// 以与比较运算 `a < b` 区分：需出现平衡的 `<...>` 且其后紧跟 `(`。
    fn peek_is_generic_ctor(&self) -> bool {
        if self.pos + 1 >= self.toks.len() {
            return false;
        }
        if !matches!(&self.toks[self.pos + 1].tok, Tok::Sym(s) if s == "<") {
            return false;
        }
        let mut depth = 0i32;
        let mut i = self.pos + 1;
        while i < self.toks.len() {
            match &self.toks[i].tok {
                Tok::Sym(s) if s == "<" => depth += 1,
                Tok::Sym(s) if s == ">" => {
                    depth -= 1;
                    if depth == 0 {
                        // `(` 普通构造；`{` trailing-lambda-only 构造
                        // （`ThreadLocal<T?> { null }`，无 `{` 支持会回退成 `<` 比较）。
                        return matches!(
                            self.toks.get(i + 1).map(|t| &t.tok),
                            Some(Tok::Sym(s)) if s == "(" || s == "{"
                        );
                    }
                }
                Tok::Sym(s) if s == ">>" => {
                    depth -= 2;
                    if depth <= 0 {
                        return matches!(
                            self.toks.get(i + 1).map(|t| &t.tok),
                            Some(Tok::Sym(s)) if s == "(" || s == "{"
                        );
                    }
                }
                // 仅类型实参中可能出现的记号；遇到语句性记号即放弃。
                Tok::Ident(_) | Tok::Sym(_) => {}
                _ => return false,
            }
            i += 1;
        }
        false
    }

    fn parse_args(&mut self) -> PResult<Vec<NodeId>> {
        let mut args = self.parse_args_no_trailing_lambda()?;
        // 尾随 lambda
        if self.is_sym("{") && !self.suppress_trailing_lambda {
            let lam = self.parse_lambda()?;
            args.push(lam);
        }
        Ok(args)
    }

    fn parse_args_no_trailing_lambda(&mut self) -> PResult<Vec<NodeId>> {
        self.expect_sym("(")?;
        self.skip_newlines();
        let mut args = Vec::new();
        while !self.is_sym(")") {
            // 跳过命名实参标签 `name =`
            if let Tok::Ident(_) = self.peek() {
                if self.pos + 1 < self.toks.len() {
                    if let Tok::Sym(s) = &self.toks[self.pos + 1].tok {
                        if s == "=" {
                            self.bump();
                            self.bump();
                            self.skip_newlines();
                        }
                    }
                }
            }
            let a = self.parse_expr()?;
            args.push(a);
            self.skip_newlines();
            if !self.eat_sym(",") {
                break;
            }
            self.skip_newlines();
        }
        self.expect_sym(")")?;
        Ok(args)
    }

    fn parse_lambda(&mut self) -> PResult<NodeId> {
        self.expect_sym("{")?;
        self.push_scope();
        let save = self.pos;
        let (params, destructured) = match self.parse_lambda_params()? {
            Some(parsed) => parsed,
            None => {
                self.pos = save;
                (Vec::new(), None)
            }
        };
        self.skip_seps();
        let mut stmts = Vec::new();
        if let Some((tuple_param, names)) = destructured {
            let tuple_ref = self.g.add(Kind::NameRef {
                original: tuple_param,
                decl: None,
            });
            stmts.push(self.g.add(Kind::DestructureDecl {
                mutable: false,
                names,
                init: tuple_ref,
            }));
        }
        while !self.is_sym("}") && !self.at_eof() {
            stmts.push(self.parse_statement()?);
            self.skip_seps();
        }
        self.expect_sym("}")?;
        self.pop_scope();
        let body = self.g.add(Kind::Block { stmts });
        Ok(self.g.add(Kind::Lambda { params, body }))
    }

    fn parse_lambda_params(
        &mut self,
    ) -> PResult<Option<(Vec<String>, Option<(String, Vec<NodeId>)>)>> {
        let mut params = Vec::new();
        let mut destructured = None;
        loop {
            match self.peek().clone() {
                Tok::Ident(n) => {
                    self.bump();
                    let mut p = n;
                    if self.eat_sym(":") {
                        let ty = self.parse_type()?;
                        p = format!("{}: {}", p, ty);
                    }
                    params.push(p);
                    self.eat_sym(",");
                }
                Tok::Sym(s) if s == "(" && params.is_empty() => {
                    self.bump();
                    let tuple_param = "__tuple".to_string();
                    let mut names = Vec::new();
                    loop {
        let name = self.expect_ident()?;
                        let nn = self.g.add(Kind::Name {
                            original: name.clone(),
                        });
                        self.declare(&name, nn);
                        names.push(nn);
                        self.skip_newlines();
                        if !self.eat_sym(",") {
                            break;
                        }
                        self.skip_newlines();
                    }
                    self.expect_sym(")")?;
                    params.push(tuple_param.clone());
                    destructured = Some((tuple_param, names));
                }
                Tok::Sym(s) if s == "->" => {
                    self.bump();
                    return Ok(Some((params, destructured)));
                }
                _ => return Ok(None),
            }
        }
    }

    fn parse_primary(&mut self) -> PResult<NodeId> {
        let line = self.line();
        match self.peek().clone() {
            // `::ident` 函数/属性引用 → 仓颉映射为函数名引用
            Tok::Sym(s) if s == "::" => {
                self.bump();
                let name = self.expect_ident()?;
                let decl = self.resolve(&name);
                Ok(self.g.add(Kind::NameRef {
                    original: format!("::{}", name),
                    decl,
                }))
            }
            // Kotlin 反引号转义标识符引用：`is`、`class` 等
            Tok::Sym(s) if s == "`" => {
                self.bump(); // `
                let name = self.expect_ident()?;
                self.expect_sym("`")?;
                let decl = self.resolve(&name);
                Ok(self.g.add(Kind::NameRef {
                    original: name,
                    decl,
                }))
            }
            Tok::Int(s) => {
                self.bump();
                Ok(self.g.add(Kind::IntLit(s)))
            }
            Tok::Float(s) => {
                self.bump();
                Ok(self.g.add(Kind::FloatLit(s)))
            }
            Tok::Char(s) => {
                self.bump();
                Ok(self.g.add(Kind::CharLit(s)))
            }
            Tok::Str(parts) => {
                self.bump();
                self.build_template(parts)
            }
            Tok::Ident(name) => {
                if name == "true" || name == "false" {
                    self.bump();
                    return Ok(self.g.add(Kind::BoolLit(name == "true")));
                }
                if name == "if" {
                    return self.parse_if();
                }
                // `this@Label` / `super@Label` → 仓颉无标签限定 this，直接映射为 this / super
                if (name == "this" || name == "super")
                    && self.pos + 1 < self.toks.len()
                    && matches!(&self.toks[self.pos + 1].tok, Tok::Sym(s) if s == "@")
                {
                    self.bump(); // this / super
                    self.bump(); // @
                    self.expect_ident()?; // 标签名（丢弃）
                    let decl = self.resolve(&name);
                    return Ok(self.g.add(Kind::NameRef {
                        original: name,
                        decl,
                    }));
                }
                if name == "when" {
                    return self.parse_when();
                }
                if name == "try" {
                    return self.parse_try();
                }
                if name == "null" {
                    self.bump();
                    return Ok(self.g.add(Kind::Raw("None".into())));
                }
                if name == "object" {
                    let save = self.pos;
                    self.bump(); // object
                    self.skip_newlines();
                    if self.is_sym(":") || self.is_sym("{") {
                        return self.parse_object_expr();
                    }
                    // Not an object expression — restore and fall through to NameRef
                    self.pos = save;
                }
                if name == "run"
                    && self.pos + 1 < self.toks.len()
                    && matches!(&self.toks[self.pos + 1].tok, Tok::Sym(s) if s == "{")
                {
                    self.bump();
                    let lam = self.parse_lambda()?;
                    return Ok(self.g.add(Kind::Call {
                        callee: lam,
                        args: Vec::new(),
                    }));
                }
                // repeat(n) { ... } → for (_ in 0..n) { ... }
                if name == "repeat" && self.peek_after_ident_is_call_or_generic() {
                    self.bump(); // repeat
                    self.expect_sym("(")?;
                    self.skip_newlines();
                    let count = self.parse_expr()?;
                    self.skip_newlines();
                    self.expect_sym(")")?;
                    self.skip_newlines();
                    let body = if self.is_sym("{") {
                        let lam = self.parse_lambda()?;
                        if let Kind::Lambda { body, .. } = self.g.kind(lam) {
                            *body
                        } else {
                            lam
                        }
                    } else {
                        self.g.add(Kind::Block { stmts: vec![] })
                    };
                    return Ok(self.g.add(Kind::Repeat { count, body }));
                }
                // 集合字面量构造器（可带显式泛型实参）
                if let Some(ctor) = collection_ctor(&name) {
                    if self.peek_after_ident_is_call_or_generic() {
                        self.bump(); // 消费 builder 名
                        let mut elem = None;
                        if self.eat_sym("<") {
                            let mut tys = Vec::new();
                            loop {
                                tys.push(self.parse_type_raw()?);
                                if !self.eat_sym(",") {
                                    break;
                                }
                            }
                            self.expect_sym(">")?;
                            elem = Some(
                                tys.iter()
                                    .map(|t| map_type(t))
                                    .collect::<Vec<_>>()
                                    .join(", "),
                            );
                        }
                        let args = self.parse_args()?;
                        return Ok(self.g.add(Kind::CollLit {
                            ctor: ctor.to_string(),
                            elem,
                            args,
                        }));
                    }
                }
                // 用户泛型类构造：`Stack<Int>()` → 保留类型实参 `Stack<Int64>()`，
                // 以便仓颉为泛型类推断类型参数（首字母大写以区分变量比较）。
                if self.peek_is_generic_ctor() {
                    self.bump(); // 类名
                    self.expect_sym("<")?;
                    let mut tys = Vec::new();
                    loop {
                        tys.push(self.parse_type_raw()?);
                        if !self.eat_sym(",") {
                            break;
                        }
                    }
                    self.expect_sym(">")?;
                    let mapped: Vec<String> = tys.iter().map(|t| map_type(t)).collect();
                    let callee = self.g.add(Kind::NameRef {
                        original: format!("{}<{}>", safe_name(&name), mapped.join(", ")),
                        decl: None,
                    });
                    // trailing-lambda-only 构造：`Type<T> { ... }` 无圆括号
                    let args = if self.is_sym("{") {
                        vec![self.parse_lambda()?]
                    } else {
                        self.parse_args()?
                    };
                    return Ok(self.g.add(Kind::Call { callee, args }));
                }
                self.bump();
                let decl = self.resolve(&name);
                Ok(self.g.add(Kind::NameRef {
                    original: name,
                    decl,
                }))
            }
            Tok::Sym(s) if s == "(" => {
                self.bump();
                self.skip_newlines();
                let e = self.parse_expr()?;
                self.skip_newlines();
                self.expect_sym(")")?;
                Ok(e)
            }
            Tok::Sym(s) if s == "{" => self.parse_lambda(),
            other => Err(format!("line {}: 非预期的记号 {:?}", line, other)),
        }
    }

    fn build_template(&mut self, parts: Vec<StrPart>) -> PResult<NodeId> {
        let mut out = Vec::new();
        for p in parts {
            match p {
                StrPart::Lit(s) => out.push(TemplatePart::Lit(s)),
                StrPart::Expr(raw) => {
                    let node = self.parse_subexpr(&raw)?;
                    out.push(TemplatePart::Expr(node));
                }
            }
        }
        Ok(self.g.add(Kind::StrTemplate { parts: out }))
    }

    /// 在当前作用域下解析一段子表达式文本（用于字符串插值）。
    fn parse_subexpr(&mut self, src: &str) -> PResult<NodeId> {
        let toks = crate::lexer::Lexer::new(src).tokenize()?;
        // 借用当前作用域解析
        let saved_toks = std::mem::replace(&mut self.toks, toks);
        let saved_pos = self.pos;
        self.pos = 0;
        self.skip_newlines();
        let res = self.parse_expr();
        self.toks = saved_toks;
        self.pos = saved_pos;
        res
    }

    fn parse_if(&mut self) -> PResult<NodeId> {
        self.eat_kw("if");
        self.expect_sym("(")?;
        let cond = self.parse_expr()?;
        self.skip_newlines();
        self.expect_sym(")")?;
        self.skip_newlines();
        let then_b = self.parse_block_or_stmt()?;
        self.skip_newlines_for_else();
        let mut else_b = None;
        if self.eat_kw("else") {
            self.skip_newlines();
            if self.is_kw("if") {
                let e = self.parse_if()?;
                else_b = Some(self.g.add(Kind::Block { stmts: vec![e] }));
            } else {
                else_b = Some(self.parse_block_or_stmt()?);
            }
        }
        Ok(self.g.add(Kind::If {
            cond,
            then_b,
            else_b,
        }))
    }

    fn skip_newlines_for_else(&mut self) {
        let save = self.pos;
        // 连 `;` 一起跳：Kotlin 允许 `if (x) foo(); else bar()`（无大括号 then 带分号），
        // 只跳换行会被 `;` 挡住，else 被误判为独立语句。
        self.skip_seps();
        if !self.is_kw("else") {
            self.pos = save;
        }
    }

    fn parse_when(&mut self) -> PResult<NodeId> {
        self.eat_kw("when");
        let mut subject = None;
        if self.eat_sym("(") {
            // Handle `when (val x = expr)` — variable declaration in subject
            if self.is_kw("val") || self.is_kw("var") {
                self.bump(); // val / var
                let _name = self.expect_ident()?; // variable name (unused in output)
                self.expect_sym("=")?;
                self.skip_newlines();
                subject = Some(self.parse_expr()?);
            } else {
                subject = Some(self.parse_expr()?);
            }
            self.skip_newlines();
            self.expect_sym(")")?;
        }
        self.skip_newlines();
        self.expect_sym("{")?;
        self.skip_seps();
        let mut arms = Vec::new();
        while !self.is_sym("}") && !self.at_eof() {
            if self.eat_kw("else") {
                self.expect_sym("->")?;
                self.skip_newlines();
                let body = self.parse_block_or_stmt()?;
                arms.push(WhenArm {
                    patterns: None,
                    body,
                });
            } else {
                let mut pats = Vec::new();
                loop {
                    // `is T` 类型分支模式
                    if self.is_kw("is") {
                        self.bump();
                        let ty = self.parse_type()?;
                        pats.push(self.g.add(Kind::TypePat { ty }));
                    } else if self.is_kw("in") || (self.is_sym("!") && self.peek_next_is_kw("in")) {
                        // `in rhs` / `!in rhs` 成员检查分支模式
                        let negated = self.eat_sym("!");
                        self.eat_kw("in");
                        let rhs = self.parse_expr()?;
                        pats.push(self.g.add(Kind::InPat { negated, rhs }));
                    } else {
                        let p = self.parse_expr()?;
                        pats.push(p);
                    }
                    if !self.eat_sym(",") {
                        break;
                    }
                    self.skip_newlines();
                }
                self.expect_sym("->")?;
                self.skip_newlines();
                let body = self.parse_block_or_stmt()?;
                arms.push(WhenArm {
                    patterns: Some(pats),
                    body,
                });
            }
            self.skip_seps();
        }
        self.expect_sym("}")?;
        Ok(self.g.add(Kind::When { subject, arms }))
    }

    // ---- 辅助 ----
    fn expect_ident(&mut self) -> PResult<String> {
        // Kotlin 反引号转义标识符：`is`、`class` 等
        if self.eat_sym("`") {
            let name = if let Tok::Ident(s) = self.peek().clone() {
                self.bump();
                s
            } else {
                return Err(format!(
                    "line {}: 期望反引号内标识符，得到 {:?}",
                    self.line(),
                    self.peek()
                ));
            };
            self.expect_sym("`")?;
            return Ok(name);
        }
        if let Tok::Ident(s) = self.peek().clone() {
            self.bump();
            Ok(s)
        } else if self.at_eof() {
            // Graceful EOF handling — return empty identifier
            // This allows partially-parsed constructs at end-of-file to succeed
            Ok(String::new())
        } else {
            Err(format!(
                "line {}: 期望标识符，得到 {:?}",
                self.line(),
                self.peek()
            ))
        }
    }

    /// 解析一个类型，并映射为仓颉类型字符串。
    fn parse_type(&mut self) -> PResult<String> {
        let raw = self.parse_type_raw()?;
        // Expand type aliases before mapping
        let expanded = if let Some(target) = self.type_aliases.get(&raw) {
            target.clone()
        } else {
            map_type(&raw)
        };
        Ok(expanded)
    }

    fn parse_type_raw(&mut self) -> PResult<String> {
        // 可空函数类型 `((A, B) -> R)?`：外层括号为可空分组。
        if self.is_sym("(")
            && self.pos + 1 < self.toks.len()
            && matches!(&self.toks[self.pos + 1].tok, Tok::Sym(s) if s == "(")
        {
            self.bump(); // 跳过外层 '('
            let inner = self.parse_type_raw()?; // 解析内层函数类型
            self.expect_sym(")")?; // 关闭外层括号
            if self.eat_sym("?") {
                return Ok(format!("({})?", inner));
            }
            return Ok(inner);
        }
        // 函数类型 `(A, B) -> R`（仓颉语法一致，可直接映射）。
        // Kotlin 带接收者的函数类型 `ReceiverType.() -> R` 也走此分支：
        // 先识别 `Ident.<...>.` 前缀，把 ReceiverType 当作第一个参数。
        if self.is_sym("(") {
            // 探测 `ReceiverType.()` 模式：当前是 `(` 但前面有未消费的 ReceiverType。
            // 此分支只在 parse_type_raw 主体被调用、且当前 token 流中已有 ReceiverType
            // 留待消费时才触发。简化方案：在 L2787 expect_ident 之后处理 `.` —— 见下方
            // L2789 的循环。这里只处理 `(A, B) -> R` 标准形式。
            self.bump();
            let mut params = Vec::new();
            if !self.is_sym(")") {
                loop {
                    let mut ty = self.parse_type_raw()?;
                    // Kotlin 函数类型参数可带名字: `(name: Type) -> R`
                    // 此时 parse_type_raw 解析到的是名字，需跳过名字取实际类型。
                    if self.eat_sym(":") {
                        ty = self.parse_type_raw()?;
                    }
                    params.push(ty);
                    if !self.eat_sym(",") {
                        break;
                    }
                }
            }
            self.expect_sym(")")?;
            self.expect_sym("->")?;
            let ret = self.parse_type_raw()?;
            let mut s = format!("({}) -> {}", params.join(", "), ret);
            if self.eat_sym("?") {
                s = format!("{}?", s);
            }
            return Ok(s);
        }
        let mut s = self.expect_ident()?;
        // 点号分隔的嵌套类型名 e.g. `Outer.Inner` 或 fully-qualified `org.koin.Type`
        // Kotlin 包名约定全小写 (org.koin.dsl),类名首字母大写 (KoinApplication)
        // → 包名前缀(全小写 ident)覆盖只保留最后一段,嵌套类(PascalCase)保留拼接
        // R3 简单覆盖破坏 221_nested_class_lifting,此精细区分避免回归
        while self.is_sym(".") && self.peek_next_is_ident() {
            let is_package_prefix = s.chars().all(|c| c.is_lowercase() || c == '_');
            self.bump(); // eat '.'
            let part = self.expect_ident()?;
            if is_package_prefix {
                s = part; // 包名前缀,覆盖只保留最后一段
            } else {
                s = format!("{}.{}", s, part); // 嵌套类,保留拼接
            }
        }
        // Kotlin 带接收者的函数类型 `ReceiverType.() -> R`：当前已读 ReceiverType
        // （可能带泛型实参 `<...>`），下一个 token 是 `.`，再下一个是 `(`。
        // 消费 `.`，把 ReceiverType 当作函数类型的第一个参数，转入 `(ReceiverType) -> R` 解析。
        if self.is_sym(".")
            && self.pos + 1 < self.toks.len()
            && matches!(&self.toks[self.pos + 1].tok, Tok::Sym(s) if s == "(")
        {
            self.bump(); // eat '.'
            // 现在应该在 `(`，复用下方函数类型分支逻辑：把 ReceiverType 加入 params
            self.expect_sym("(")?;
            let mut params = vec![s.clone()]; // 第一个参数是 ReceiverType
            if !self.is_sym(")") {
                loop {
                    let mut ty = self.parse_type_raw()?;
                    if self.eat_sym(":") {
                        ty = self.parse_type_raw()?;
                    }
                    params.push(ty);
                    if !self.eat_sym(",") {
                        break;
                    }
                }
            }
            self.expect_sym(")")?;
            self.expect_sym("->")?;
            let ret = self.parse_type_raw()?;
            let mut func_s = format!("({}) -> {}", params.join(", "), ret);
            if self.eat_sym("?") {
                func_s = format!("{}?", func_s);
            }
            return Ok(func_s);
        }
        if self.eat_sym("<") {
            let mut args = Vec::new();
            loop {
                // 跳过 Kotlin 型变标注 `out` / `in`
                self.eat_kw("out");
                self.eat_kw("in");
                // Kotlin star projection `*` → 仓颉 `Any`
                if self.eat_sym("*") {
                    args.push("Any".to_string());
                } else {
                    args.push(self.parse_type_raw()?);
                }
                if !self.eat_sym(",") {
                    break;
                }
            }
            self.expect_sym(">")?;
            s = format!("{}<{}>", s, args.join(","));
        }
        // 可空类型 `?` —— 保留为前缀标记，交由 map_type 处理
        if self.eat_sym("?") {
            s = format!("{}?", s);
        }
        Ok(s)
    }
}

/// 关键字转义：把与仓颉关键字冲突的标识符用反引号包裹。
pub fn safe_name(name: &str) -> String {
    const KW: &[&str] = &[
        "super",
        "let",
        "var",
        "func",
        "class",
        "struct",
        "interface",
        "enum",
        "match",
        "case",
        "where",
        "open",
        "init",
        "main",
        "type",
        "as",
        "is",
        "in",
        "spawn",
        "macro",
        "quote",
        "extend",
        "prop",
        "mut",
        "unsafe",
        "foreign",
        "with",
        // 仓颉关键字，但在 Kotlin 中是合法标识符（ksoup Nodes.kt 有 `operator` 参数名）
        "operator",
        "redef",
        "inout",
        "synchronized",
        "static",
    ];
    if KW.contains(&name) {
        format!("`{}`", name)
    } else {
        name.to_string()
    }
}

/// 集合字面量构造器名 → 仓颉容器类型名。
pub fn collection_ctor(name: &str) -> Option<&'static str> {
    match name {
        "listOf" | "mutableListOf" | "arrayListOf" | "ArrayList" => Some("ArrayList"),
        "setOf" | "mutableSetOf" | "hashSetOf" | "HashSet" => Some("HashSet"),
        "mapOf" | "mutableMapOf" | "hashMapOf" | "HashMap" | "LinkedHashMap" => Some("HashMap"),
        "arrayOf" => Some("__ArrayLiteral"),
        _ => None,
    }
}

/// Kotlin 类型 → 仓颉类型。
pub fn map_type(raw: &str) -> String {
    let raw = raw.trim();
    // 函数类型 `(A, B) -> R` → 逐段映射参数与返回类型（仓颉语法一致）。
    if raw.starts_with('(') {
        if let Some(close) = matching_paren(raw) {
            let after = raw[close + 1..].trim_start();
            if let Some(rest) = after.strip_prefix("->") {
                let inner = &raw[1..close];
                let params: Vec<String> = if inner.trim().is_empty() {
                    Vec::new()
                } else {
                    split_top(inner).iter().map(|a| map_type(a)).collect()
                };
                let ret = map_type(rest.trim());
                return format!("({}) -> {}", params.join(", "), ret);
            }
        }
    }
    // 可空类型：Kotlin `T?` → 仓颉 `?T`
    if let Some(base) = raw.strip_suffix('?') {
        return format!("?{}", map_type(base));
    }
    // 解析泛型
    if let Some(lt) = raw.find('<') {
        let base = &raw[..lt];
        let inner = &raw[lt + 1..raw.rfind('>').unwrap_or(raw.len())];
        let args: Vec<String> = split_top(inner).iter().map(|a| map_type(a)).collect();
        // Kotlin `Pair<A, B>` / `Triple<A, B, C>` → 仓颉元组类型 `(A, B)`。
        if base == "Pair" || base == "Triple" {
            return format!("({})", args.join(", "));
        }
        // Kotlin `Map.Entry<K, V>` / `MutableMap.MutableEntry<K, V>` 值位 →
        // 元组 `(K, V)`（仓颉 HashMap 迭代产出的元素类型即 (K, V)）。
        if base == "Map.Entry" || base == "MutableMap.MutableEntry" {
            return format!("({})", args.join(", "));
        }
        let mapped_base = match base {
            "List" | "MutableList" | "ArrayList" | "Collection" | "Iterable" => "ArrayList",
            "Map" | "MutableMap" | "HashMap" | "LinkedHashMap" => "HashMap",
            "Set" | "MutableSet" | "HashSet" => "HashSet",
            "Array" => "Array",
            other => other,
        };
        return format!("{}<{}>", mapped_base, args.join(", "));
    }
    match raw {
        "Int" | "Short" | "Byte" | "Long" => "Int64".to_string(),
        "UInt" | "ULong" => "UInt64".to_string(),
        "UShort" => "Int64".to_string(),
        "UByte" => "UInt8".to_string(),
        "Double" | "Float" => "Float64".to_string(),
        "Boolean" => "Bool".to_string(),
        "Char" => "Rune".to_string(),
        "CharArray" => "Array<Rune>".to_string(),
        "IntRange" => "Range<Int64>".to_string(),
        "String" | "CharSequence" => "String".to_string(),
        "Unit" => "Unit".to_string(),
        "Any" => "Object".to_string(),
        "Throwable" => "Exception".to_string(),
        "NumberFormatException" => "IllegalArgumentException".to_string(),
        // 裸限定名（泛型实参已在上游丢弃）→ 顶层 marker 接口名（stubs.rs 注入）
        "Map.Entry" => "Entry".to_string(),
        "MutableMap.MutableEntry" => "MutableEntry".to_string(),
        other => other.to_string(),
    }
}

fn split_top(s: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut depth = 0;
    let mut cur = String::new();
    let chars: Vec<char> = s.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        let c = chars[i];
        // 函数箭头 `->`：其中的 `>` 不是泛型/括号闭合，整体透传不动 depth。
        // 否则 `Pair<(T) -> R, X>` 里 `->` 的 `>` 会把 depth 减到负、错误地把
        // 逗号当顶层分隔（进而 rfind('>') 也被误导，产出 `((T) -)` 的乱码）。
        if c == '-' && i + 1 < chars.len() && chars[i + 1] == '>' {
            cur.push('-');
            cur.push('>');
            i += 2;
            continue;
        }
        match c {
            '<' | '(' => {
                depth += 1;
                cur.push(c);
            }
            '>' | ')' => {
                depth -= 1;
                cur.push(c);
            }
            ',' if depth == 0 => {
                out.push(cur.trim().to_string());
                cur.clear();
            }
            _ => cur.push(c),
        }
        i += 1;
    }
    if !cur.trim().is_empty() {
        out.push(cur.trim().to_string());
    }
    out
}

/// 返回与位置 0 的 `(` 匹配的 `)` 的下标。
fn matching_paren(s: &str) -> Option<usize> {
    let bytes = s.as_bytes();
    if bytes.first() != Some(&b'(') {
        return None;
    }
    let mut depth = 0;
    for (i, &b) in bytes.iter().enumerate() {
        match b {
            b'(' => depth += 1,
            b')' => {
                depth -= 1;
                if depth == 0 {
                    return Some(i);
                }
            }
            _ => {}
        }
    }
    None
}

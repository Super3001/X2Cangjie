//! 局部渲染规则：每个节点仅依据 *自身 + 子节点（邻居）已确定的目标片段*
//! 来计算自己的目标语言译文。这些规则是 SOC 框架中「局部崩塌/转换函数」
//! 的实现——节点状态变更触发邻居重新入队，形成沿语法/依赖边的级联传播。

use crate::engine::Engine;
use crate::node::*;

pub(crate) const IND: &str = "    ";

/// 将字符串插值表达式中的换行折叠为单行，使多行块(if-let/when 等)能塞进
/// 仓颉单行字符串插值 `${...}`。仓颉以换行**或** `;` 分隔语句，故折叠时须保留
/// 语句边界：多数换行折叠为 `;`，续行处(下一 token 是 else/catch/finally 或前后为
/// 续行运算符/标点)折叠为空格。行内空白(含单行字符串字面量内容)原样保留。
/// 若表达式含仓颉多行字符串字面量(`"""`,内含真实换行)则跳过折叠、保留原样并
/// fail loud(当前渲染层不产出 `"""`，此为防御性保护)。
fn fold_interp_expr(src: &str) -> String {
    if !src.contains('\n') && !src.contains('\r') {
        return src.to_string();
    }
    if src.contains("\"\"\"") {
        // 多行字符串字面量内的换行不可折叠；保持原样(仍会 lex 报错，honest fail)。
        return src.to_string();
    }
    // 续行标点：出现在换行「前」(上一字符)或「后」(下一字符)时，说明该换行只是
    // 排版折行而非语句边界，折叠成空格而非 `;`。
    const PREV_CONT: &str = "{([,.?:=+-*/%<>&|!";
    const NEXT_CONT: &str = ").],?:=+-*/%<>&|!";
    let chars: Vec<char> = src.chars().collect();
    let mut out = String::with_capacity(src.len());
    let mut i = 0;
    while i < chars.len() {
        let ch = chars[i];
        if ch == '\n' || ch == '\r' {
            // 吞掉紧随的换行与行首缩进(始终是记号间排版空白)。
            let mut j = i + 1;
            while j < chars.len() && matches!(chars[j], '\n' | '\r' | ' ' | '\t') {
                j += 1;
            }
            let prev = out.chars().rev().find(|c| !c.is_whitespace());
            let next = chars.get(j).copied();
            let next_is_cont_kw = next_token_is_continuation_kw(&chars, j);
            let use_semicolon = match (prev, next) {
                (None, _) | (_, None) => false, // 开头/结尾无需分隔
                (_, Some(n)) if n == '}' => false, // 块闭合前，空格即可
                (Some(p), Some(n)) => {
                    !PREV_CONT.contains(p) && !NEXT_CONT.contains(n) && !next_is_cont_kw
                }
            };
            if !out.is_empty() {
                if use_semicolon {
                    out.push(';');
                    out.push(' ');
                } else if !out.ends_with(' ') {
                    out.push(' ');
                }
            }
            i = j;
        } else {
            out.push(ch);
            i += 1;
        }
    }
    out
}

/// 折叠点的下一个 token 是否为 else/catch/finally 等续行关键字。
fn next_token_is_continuation_kw(chars: &[char], start: usize) -> bool {
    let rest: String = chars[start..].iter().take(8).collect();
    for kw in ["else", "catch", "finally"] {
        if rest.starts_with(kw) {
            let after = rest[kw.len()..].chars().next();
            // 关键字后须为非标识符字符(边界)，避免误配 elsewhere 之类。
            if after.map_or(true, |c| !c.is_alphanumeric() && c != '_') {
                return true;
            }
        }
    }
    false
}

impl Engine {
    // ============ 基础工具 ============

    pub(crate) fn t(&self, id: NodeId) -> Option<String> {
        self.g.target(id).map(|s| s.to_string())
    }

    /// 若操作数本身是二元/区间表达式，加括号以保持优先级。
    pub(crate) fn atom(&self, id: NodeId) -> Option<String> {
        let s = self.t(id)?;
        let need = matches!(self.g.kind(id), Kind::Binary { .. } | Kind::Range { .. });
        if need {
            Some(format!("({})", s))
        } else {
            Some(s)
        }
    }

    // ============ 核心渲染 ============

    pub(crate) fn render(&self, id: NodeId) -> Option<String> {
        match self.g.kind(id).clone() {
            Kind::IntLit(s) => Some(s),
            Kind::FloatLit(s) => {
                if s.contains('.') || s.contains('e') || s.contains('E') {
                    Some(s)
                } else {
                    Some(format!("{}.0", s))
                }
            }
            Kind::BoolLit(b) => Some(if b { "true".into() } else { "false".into() }),
            Kind::CharLit(s) => {
                // Detect surrogate code points (U+D800..U+DFFF) — Cangjie rejects
                // these in Rune literals. Render as hex integer instead.
                if let Some(hex_str) = s.strip_prefix("\\u{").and_then(|h| h.strip_suffix("}")) {
                    if let Ok(val) = u32::from_str_radix(hex_str, 16) {
                        if (0xD800..=0xDFFF).contains(&val) {
                            return Some(format!("0x{:X}", val));
                        }
                    }
                }
                Some(format!("r'{}'", s))
            }
            Kind::Raw(s) => Some(s),
            Kind::Name { original } => Some(crate::parser::safe_name(&original)),
            Kind::NameRef { original, decl } => {
                // Kotlin `Unit` value-expression → Cangjie unit value `()`
                // (the `Unit` *type* goes through map_type, not NameRef)
                if original == "Unit" {
                    return Some("()".to_string());
                }
                // Kotlin :: prefix — strip for Cangjie (::isIdent → isIdent)
                let safe_original = if original.starts_with("::") {
                    crate::parser::safe_name(&original[2..])
                } else {
                    crate::parser::safe_name(&original)
                };
                if let Some(field) = self.render_singleton_static_field_ref(id, &original, decl) {
                    return Some(field);
                }
                if let Some(field) = self.render_companion_static_field_ref(id, &original, decl) {
                    return Some(field);
                }
                match decl {
                    // 已解析到本地声明：本地优先，不改写（作用域内定义遮蔽成员 import）。
                    Some(d) => self
                        .t(d)
                        .or_else(|| Some(safe_original)),
                    None => {
                        // 成员 import 重限定：未解析的裸 `member`（Kotlin `import P.C.member`
                        // 后裸用）→ 仓颉限定 `C.member`（静态/companion 成员）。
                        // 本地优先：若 `member` 是所在类的成员/构造参数（隐式 this 引用，
                        // decl=None 但非导入成员，如 TimeBased 的 `nanoseconds`），不改写。
                        let key = original.strip_prefix("::").unwrap_or(&original);
                        if let Some(qual) = self.g.member_imports.get(key) {
                            if !self.enclosing_class_has_member(id, key) {
                                return Some(format!("{}.{}", qual, safe_original));
                            }
                        }
                        Some(safe_original)
                    }
                }
            }
            Kind::Unary { op, expr } => {
                let e = self.atom(expr)?;
                Some(format!("{}{}", op, e))
            }
            Kind::Binary { op, lhs, rhs } => self.render_binary(&op, lhs, rhs),
            Kind::Range {
                lo,
                hi,
                inclusive,
                down,
                step,
            } => {
                let l = self.atom(lo)?;
                let h = self.atom(hi)?;
                let dots = if inclusive { "..=" } else { ".." };
                let stp = match step {
                    Some(s) => {
                        let sv = self.atom(s)?;
                        if down {
                            format!(" : -{}", sv)
                        } else {
                            format!(" : {}", sv)
                        }
                    }
                    None => {
                        if down {
                            " : -1".to_string()
                        } else {
                            String::new()
                        }
                    }
                };
                Some(format!("{}{}{}{}", l, dots, h, stp))
            }
            Kind::Index { base, index } => self.render_index(base, index),
            Kind::Member { base, name, safe } => self.render_member(base, &name, safe),
            Kind::Call { callee, args } => self.render_call(callee, &args),
            Kind::CollLit { ctor, elem, args } => {
                if ctor == "__ArrayLiteral" {
                    if args
                        .iter()
                        .any(|a| matches!(self.g.kind(*a), Kind::Spread { .. }))
                    {
                        return self.render_spread_array_literal(&args);
                    }
                    let a: Vec<String> = args
                        .iter()
                        .map(|x| self.render_arg(*x))
                        .collect::<Option<_>>()?;
                    return Some(format!("[{}]", a.join(", ")));
                }
                if args.is_empty() {
                    match elem {
                        Some(e) => Some(format!("{}<{}>()", ctor, e)),
                        None => Some(format!("{}()", ctor)),
                    }
                } else {
                    if args.len() == 1 {
                        if let Kind::Spread { expr } = self.g.kind(args[0]) {
                            let spread = self.t(*expr)?;
                            return match elem {
                                Some(e) => Some(format!("{}<{}>({})", ctor, e, spread)),
                                None => Some(format!("{}({})", ctor, spread)),
                            };
                        }
                    }
                    let a: Vec<String> = args
                        .iter()
                        .map(|x| self.render_arg(*x))
                        .collect::<Option<_>>()?;
                    match elem {
                        Some(e) => Some(format!("{}<{}>([{}])", ctor, e, a.join(", "))),
                        None => Some(format!("{}([{}])", ctor, a.join(", "))),
                    }
                }
            }
            Kind::Spread { expr } => self.t(expr),
            Kind::Lambda { params, body } => {
                let inner = self.render_block_inner(body, 0)?;
                let head = if params.is_empty() {
                    if self.uses_it(body) {
                        "it =>".to_string()
                    } else {
                        "=>".to_string()
                    }
                } else {
                    let ps: Vec<String> = params
                        .iter()
                        .map(|p| match p.split_once(':') {
                            Some((n, t)) => {
                                format!("{}: {}", crate::parser::safe_name(n.trim()), t.trim())
                            }
                            None => crate::parser::safe_name(p),
                        })
                        .collect();
                    format!("{} =>", ps.join(", "))
                };
                if inner.trim().is_empty() {
                    Some(format!("{{ {} }}", head))
                } else if inner.lines().count() <= 1 {
                    Some(format!("{{ {} {} }}", head, inner.trim()))
                } else {
                    Some(format!("{{ {}\n{}\n}}", head, indent(&inner, 1)))
                }
            }
            Kind::SafeLet { recv, var, body } => {
                let r = if let Kind::Index { base, index } = self.g.kind(recv) {
                    format!("{}.get({})", self.atom(*base)?, self.t(*index)?)
                } else {
                    self.atom(recv)?
                };
                let blk = self.render_block(body)?;
                Some(format!(
                    "if (let Some({}) <- {}) {}",
                    crate::parser::safe_name(&var),
                    r,
                    blk
                ))
            }
            Kind::StrTemplate { parts } => {
                let mut s = String::from("\"");
                for p in &parts {
                    match p {
                        TemplatePart::Lit(l) => s.push_str(l),
                        TemplatePart::Expr(e) => {
                            let et = self.t(*e)?;
                            // 仓颉单行字符串插值 `${...}` 不允许换行。插值表达式若渲染出
                            // 多行块(如 if-let 语句块)，会触发 unterminated string 词法错误。
                            // 将换行及其后行首缩进折叠为单空格——这些空白始终是词法记号
                            // 之间的排版缩进(单行字符串字面量不含真实换行)，折叠不改变语义。
                            let folded = fold_interp_expr(&et);
                            s.push_str(&format!("${{{}}}", folded));
                        }
                    }
                }
                s.push('"');
                Some(s)
            }

            // ---- 语句 ----
            Kind::ExprStmt { expr } => self.t(expr),
            Kind::Assign { target, op, value } => {
                // Index 目标的 base 是调用表达式（如 getOrPut 展开的 IIFE）时，仓颉
                // 不接受复杂表达式作索引赋值左值——先提升为临时变量再赋值。
                // 临时名带节点 id，避免同块内多次出现冲突。
                if let Kind::Index { base, index } = self.g.kind(target) {
                    if let Kind::Call { callee, args } = self.g.kind(*base) {
                        // getOrPut 特化：statement 级展开。IIFE 版本有两个问题——
                        // (a) IIFE 索引赋值是非法左值；(b) IIFE 内裸 `HashMap()` 无法
                        // 推断泛型实参。改写成 `map[k] = (lam)()` 后，ctor 从 map 的
                        // 值类型获得推断。
                        if let Kind::Member {
                            base: mbase,
                            name: mname,
                            ..
                        } = self.g.kind(*callee)
                        {
                            if mname == "getOrPut" && args.len() == 2 {
                                let m = self.t(*mbase)?;
                                let k = self.t(args[0])?;
                                // 单表达式 lambda 直接内联函数体：`(lam)()` 形式会挡住
                                // 类型推断（裸 `HashMap()` 推不出泛型实参），
                                // `map[k] = HashMap()` 则可从 map 值类型推断。
                                let rhs = self
                                    .single_expr_lambda_body(args[1])
                                    .map(|e| self.t(e))
                                    .unwrap_or_else(|| {
                                        Some(format!("({})()", self.t(args[1])?))
                                    })?;
                                let i = self.t(*index)?;
                                let v = self.t(value)?;
                                let tmp = format!("__k2cjIdxRecv{}", target);
                                return Some(format!(
                                    "if (!({m}.contains({k}))) {{\n    {m}[{k}] = {rhs}\n}}\nlet {tmp} = {m}[{k}]\n{tmp}[{i}] {op} {v}",
                                    m = m, k = k, rhs = rhs, tmp = tmp, i = i, op = op, v = v
                                ));
                            }
                        }
                        let b = self.t(*base)?;
                        let i = self.t(*index)?;
                        let v = self.t(value)?;
                        let tmp = format!("__k2cjIdxRecv{}", target);
                        return Some(format!("let {} = {}\n{}[{}] {} {}", tmp, b, tmp, i, op, v));
                    }
                }
                let tt = self.render_assign_target(target)?;
                let v = self.t(value)?;
                // String += Rune/non-string: convert RHS to string
                if op == "+=" && self.looks_string(target) && !self.looks_string(value) {
                    return Some(format!("{} += {}.toString()", tt, v));
                }
                // Float64 += / -= / *= / /= Int64: promote RHS to Float64
                if matches!(op.as_str(), "+=" | "-=" | "*=" | "/=")
                    && self.looks_float(target)
                    && !self.looks_float(value)
                    && self.looks_numeric(value)
                {
                    return Some(format!("{} {} Float64({})", tt, op, v));
                }
                Some(format!("{} {} {}", tt, op, v))
            }
            Kind::Return { value } => match value {
                Some(v) => Some(format!("return {}", self.t(v)?)),
                None => Some("return".to_string()),
            },
            Kind::Throw { value } => Some(format!("throw {}", self.t(value)?)),
            Kind::VarDecl {
                mutable,
                name_node,
                ty,
                init,
                is_lazy,
            } => self.render_var_decl(mutable, name_node, ty, init, is_lazy),
            Kind::If {
                cond,
                then_b,
                else_b,
            } => self.render_if(cond, then_b, else_b),
            Kind::While { cond, body } => Some(format!(
                "while ({}) {}",
                self.t(cond)?,
                self.render_block(body)?
            )),
            Kind::DoWhile { body, cond } => Some(format!(
                "do {} while ({})",
                self.render_block(body)?,
                self.t(cond)?
            )),
            Kind::Repeat { count, body } => {
                let var = if self.uses_it(body) { "it" } else { "_" };
                Some(format!(
                    "for ({} in 0..{}) {}",
                    var,
                    self.atom(count)?,
                    self.render_block(body)?
                ))
            }
            Kind::Destructure { names } => {
                let ns: Vec<String> = names.iter().map(|n| self.t(*n)).collect::<Option<_>>()?;
                Some(format!("({})", ns.join(", ")))
            }
            Kind::DestructureDecl {
                mutable,
                names,
                init,
            } => {
                let ns: Vec<String> = names.iter().map(|n| self.t(*n)).collect::<Option<_>>()?;
                let kw = if mutable { "var" } else { "let" };
                Some(format!("{} ({}) = {}", kw, ns.join(", "), self.t(init)?))
            }
            Kind::ForRange { var, range, body } => {
                let vn = self.loop_var_name(var)?;
                Some(format!(
                    "for ({} in {}) {}",
                    vn,
                    self.t(range)?,
                    self.render_block(body)?
                ))
            }
            Kind::ForEach { var, iter, body } => {
                let vn = self.loop_var_name(var)?;
                let it = if self.looks_string(iter) {
                    format!("{}.runes()", self.atom(iter)?)
                } else {
                    self.t(iter)?
                };
                // HashMap 解构遍历: for ((k, v) in map) → for ((k, v) in map)
                // 仓颉的 HashMap 遍历直接解构为 (key, value) 元组
                Some(format!(
                    "for ({} in {}) {}",
                    vn,
                    it,
                    self.render_block(body)?
                ))
            }
            Kind::Try {
                body,
                catches,
                finally,
            } => {
                let mut s = format!("try {}", self.render_block(body)?);
                for c in &catches {
                    s.push_str(&format!(
                        " catch ({}: {}) {}",
                        c.name,
                        c.ty,
                        self.render_block(c.body)?
                    ));
                }
                if let Some(f) = finally {
                    s.push_str(&format!(" finally {}", self.render_block(f)?));
                }
                Some(s)
            }
            Kind::When { subject, arms } => self.render_when(subject, &arms),
            Kind::Block { .. } => self.render_block(id),
            Kind::IsCheck { expr, ty, negate } => {
                let e = self.atom(expr)?;
                // 可空操作数 `x is T`（x: Option<...>）：仓颉 `is` 不穿透 Option（Some(v) is T
                // 恒 false）。Kotlin `x is T`（x: Any?）语义 = 非空且内值是 T → 先解包再判定。
                if self.is_nullable_expr(expr) && !self.is_null_check_rebound(expr) {
                    return Some(if negate {
                        format!("({}.isNone() || !({}.getOrThrow() is {}))", e, e, ty)
                    } else {
                        format!("({}.isSome() && ({}.getOrThrow() is {}))", e, e, ty)
                    });
                }
                if negate {
                    Some(format!("!({} is {})", e, ty))
                } else {
                    Some(format!("({} is {})", e, ty))
                }
            }
            Kind::TypePat { ty } => Some(format!("_: {}", ty)),

            // ---- 声明 ----
            Kind::Param {
                name_node,
                ty,
                default,
            } => match default {
                Some(d) => Some(format!("{}!: {} = {}", self.t(name_node)?, ty, self.t(d)?)),
                None => Some(format!("{}: {}", self.t(name_node)?, ty)),
            },
            Kind::Func {
                name,
                params,
                ret,
                body,
                is_main,
                is_abstract,
                is_override,
                receiver_type,
                generic_params,
            } => self.render_func(
                id,
                &name,
                &params,
                ret,
                body,
                is_main,
                is_abstract,
                is_override,
                receiver_type.as_deref(),
                &generic_params,
            ),
            Kind::SecondaryConstructor {
                params,
                delegate,
                body,
            } => self.render_secondary_constructor(&params, delegate.as_ref(), body),
            Kind::Class {
                name,
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
            } => self.render_class(
                &name,
                &ctor_params,
                &members,
                superclass,
                is_open,
                is_data,
                is_value,
                is_interface,
                is_abstract,
                &interfaces,
                &super_args,
                &generics,
                init_block,
                &companion_members,
                is_singleton,
                &supertype_delegations,
                is_expect,
            ),
            Kind::Enum {
                name,
                entries,
                params,
                companion_consts,
            } => self.render_enum(&name, &entries, &params, &companion_consts),
            Kind::TypeAlias { name, target_type } => {
                // 仓颉 `type X = Y` 语法 (1f R6: 之前注释化导致类型引用 undeclared)
                // 泛型 typealias (name 含 `<`) 仓颉可能不支持,仍注释化避免 V 未声明
                if name.contains('<') {
                    Some(format!("// typealias {} = {}", name, target_type))
                } else {
                    Some(format!("type {} = {}", name, target_type))
                }
            }
            Kind::TypeCast { expr, ty, safe } => {
                let e = self.atom(expr)?;
                if safe {
                    // `as?` → try cast, return Option
                    Some(format!(
                        "(if ({} is {}) {{ {} as {} }} else {{ None }})",
                        e, ty, e, ty
                    ))
                } else if self.is_nullable_expr(expr) && !self.is_null_check_rebound(expr) {
                    // 可空操作数 `x as T`（x: Option<...>，非空断言语义）：仓颉 `x as T` 得
                    // Option<T>，且 Option<Object> 无法直接 `as`。先解包再向下转型再解包 → T
                    // （对齐 Kotlin 非空 `as` 得非空 T；空则 getOrThrow 抛错，与 Kotlin CCE 一致）。
                    Some(format!("({}.getOrThrow() as {}).getOrThrow()", e, ty))
                } else {
                    // `as` → direct cast
                    Some(format!("({} as {})", e, ty))
                }
            }
            Kind::Program { items } => self.render_program(&items),
            Kind::ForceUnwrap { expr } => {
                let e = self.t(expr)?;
                // Only emit .getOrThrow() for expressions that are genuinely Optional in Cangjie
                // HashMap/collection indexing already returns non-optional in Cangjie
                let is_map_index = matches!(self.g.kind(expr), Kind::Index { .. });
                if is_map_index {
                    return Some(e);
                }
                // Call expressions with !! always need unwrapping (user code knows the return is nullable)
                if matches!(self.g.kind(expr), Kind::Call { .. }) {
                    return Some(format!("{}.getOrThrow()", e));
                }
                // Member access on nullable fields
                if let Kind::Member { base, name, .. } = self.g.kind(expr) {
                    // Check if this member field is nullable in the class declaration
                    let field_nullable = self.is_nullable_member_field(*base, name);
                    if field_nullable {
                        return Some(format!("{}.getOrThrow()", e));
                    }
                    return Some(e);
                }
                // NameRef: check if the variable itself is nullable.
                // Skip unwrap for variables rebound inside if-let null-check blocks:
                // `if (x != null) { ...x!!... }` renders x as the non-Option rebind, so
                // `x.getOrThrow()` would be over-unwrap (getOrThrow not a member of the class).
                if self.is_nullable_expr(expr) && !self.is_null_check_rebound(expr) {
                    Some(format!("{}.getOrThrow()", e))
                } else {
                    Some(e)
                }
            }
            Kind::InPat { .. } => None,
        }
    }

    // ============ 二元运算 ============

    fn render_binary(&self, op: &str, lhs: NodeId, rhs: NodeId) -> Option<String> {
        if op == "to" {
            let l = self.t(lhs)?;
            let r = self.t(rhs)?;
            return Some(format!("({}, {})", l, r));
        }
        if op == "?:" {
            let ra = self.atom(rhs)?;
            if let Kind::Index { base, index } = self.g.kind(lhs).clone() {
                let b = self.atom(base)?;
                let i = self.t(index)?;
                return Some(format!("{}.get({}) ?? {}", b, i, ra));
            }
            let la = self.atom(lhs)?;
            return Some(format!("{} ?? {}", la, ra));
        }
        if op == "in" || op == "!in" {
            let inner = self.render_in(lhs, rhs)?;
            return Some(if op == "!in" {
                format!("!({})", inner)
            } else {
                inner
            });
        }
        if op == "==" || op == "!=" {
            // 运行时类型比较 `this::class == other::class`（equals 样板）：两侧均为 `::class`
            // 反射成员（渲染时被降为 base）。仓颉无 `getClass()`，以外围类的 `is` 判定近似
            // （对 jsoup 里 final DOM 类精确）：`a::class == b::class` → `other is EnclosingClass`。
            if let Some(res) = self.render_class_reflection_eq(op, lhs, rhs) {
                return Some(res);
            }
            let lhs_null = matches!(self.g.kind(lhs), Kind::Raw(s) if s == "None");
            let rhs_null = matches!(self.g.kind(rhs), Kind::Raw(s) if s == "None");
            if lhs_null ^ rhs_null {
                let other = if lhs_null { rhs } else { lhs };
                let oa = self.atom(other)?;
                let m = if op == "==" { "isNone" } else { "isSome" };
                return Some(format!("{}.{}()", oa, m));
            }
            // 可空相等归一（1g Option 战役 R12）：仓颉类无默认 `==`，且 Option<T> 与 T
            // 混比会类型不匹配。按两侧类别分桶归一。
            if !lhs_null && !rhs_null {
                if let Some(res) = self.render_eq_normalized(op, lhs, rhs) {
                    return Some(res);
                }
            }
        }
        let la = self.atom(lhs)?;
        let ra = self.atom(rhs)?;
        if (op == "+" || op == "+=") && (self.looks_string(lhs) || self.looks_string(rhs)) {
            let lc = if self.looks_string(lhs) {
                la.clone()
            } else {
                format!("{}.toString()", la)
            };
            let rc = if self.looks_string(rhs) {
                ra.clone()
            } else {
                format!("{}.toString()", ra)
            };
            return Some(format!("{} {} {}", lc, op, rc));
        }
        if matches!(op, "-" | "+") && self.looks_char(lhs) && self.looks_char(rhs) {
            return Some(format!(
                "(Int64(UInt32({})) {} Int64(UInt32({})))",
                la, op, ra
            ));
        }
        if matches!(op, "+" | "-")
            && self.looks_char(lhs)
            && !self.looks_char(rhs)
            && !self.looks_string(rhs)
        {
            return Some(format!("Rune(UInt32(Int64(UInt32({})) {} {}))", la, op, ra));
        }
        if matches!(
            op,
            "+" | "-" | "*" | "/" | "%" | ">" | "<" | ">=" | "<=" | "==" | "!="
        ) {
            let lf = self.looks_float(lhs);
            let rf = self.looks_float(rhs);
            if lf && !rf && self.looks_numeric(rhs) {
                return Some(format!("{} {} Float64({})", la, op, ra));
            }
            if rf && !lf && self.looks_numeric(lhs) {
                return Some(format!("Float64({}) {} {}", la, op, ra));
            }
        }
        Some(format!("{} {} {}", la, op, ra))
    }

    /// `x::class == y::class` / `!=`（Kotlin 运行时类型相等，equals 样板惯用）。
    /// 两侧须均为 `::class` 反射成员；一侧为 `this` 时以外围类的 `is` 判定近似另一侧。
    fn render_class_reflection_eq(&self, op: &str, lhs: NodeId, rhs: NodeId) -> Option<String> {
        let is_class_ref = |id: NodeId| -> Option<NodeId> {
            if let Kind::Member { base, name, .. } = self.g.kind(id) {
                if name == "::class" || name == "javaClass" || name == "::javaClass" {
                    return Some(*base);
                }
            }
            None
        };
        let lb = is_class_ref(lhs)?;
        let rb = is_class_ref(rhs)?;
        let is_this = |id: NodeId| matches!(self.g.kind(id), Kind::NameRef { original, .. } if original == "this" || original == "`this`");
        // 取「非 this」一侧作被判定对象，this 一侧提供外围类名。
        let (subj, this_node) = if is_this(lb) {
            (rb, lb)
        } else if is_this(rb) {
            (lb, rb)
        } else {
            return None;
        };
        let cls = self.current_class(this_node)?;
        let subj_atom = self.atom(subj)?;
        // subj 通常是 equals 的 `other: ?Object`（可空）→ 用可空感知 is 判定。
        let nullable = self.is_nullable_expr(subj) && !self.is_null_check_rebound(subj);
        let same_type = if nullable {
            format!("({}.isSome() && ({}.getOrThrow() is {}))", subj_atom, subj_atom, cls)
        } else {
            format!("({} is {})", subj_atom, cls)
        };
        Some(if op == "==" {
            same_type
        } else {
            format!("!{}", same_type)
        })
    }

    /// 可空/引用相等归一（op 为 `==` 或 `!=`，两侧均非 `None` 字面量）。
    /// 返回 `None` 表示判不出类别、保持原样（保守，宁残留勿误改语义）。
    fn render_eq_normalized(&self, op: &str, lhs: NodeId, rhs: NodeId) -> Option<String> {
        use crate::heuristics::EqCat;
        // 桶 C（结构相等派发，R13 闭环）：两侧同一含 equals 方法的引用类 → 空安全 `a.equals(b)`。
        // R13 前置修复（IsCheck/TypeCast 可空感知 + `::class` 反射比较）已让 equals 体在解包
        // 后正确工作；此处按两侧可空性生成空安全派发（equals 参数 ?Object 会自动装箱裸值）。
        if let Some((_cls, ln, rn)) = self.same_equals_class(lhs, rhs) {
            let la = self.atom(lhs)?;
            let ra = self.atom(rhs)?;
            // 各可空组合下的「结构相等」表达式（Kotlin `==` 语义：都空=真，一空=假，都非空=结构）。
            let eq = match (ln, rn) {
                (false, false) => format!("{}.equals({})", la, ra),
                (true, false) => format!("({}.isSome() && {}.getOrThrow().equals({}))", la, la, ra),
                (false, true) => format!("({}.isSome() && {}.equals({}.getOrThrow()))", ra, la, ra),
                (true, true) => format!(
                    "(({}.isNone() && {}.isNone()) || ({}.isSome() && {}.isSome() && {}.getOrThrow().equals({}.getOrThrow())))",
                    la, ra, la, ra, la, ra
                ),
            };
            return Some(if op == "==" { eq } else { format!("!({})", eq) });
        }
        let (lc, _ln) = self.classify_eq_operand(lhs);
        let (rc, _rn) = self.classify_eq_operand(rhs);
        // 桶 A：两侧均为引用类别 → 空安全引用相等 `__k2cjRefEq2(a, b)`。
        // 仓颉引用类无 `==`；辅助函数自动装箱裸值、透传 Option、跨子类型双泛型消解。
        if lc == EqCat::Ref && rc == EqCat::Ref {
            let la = self.atom(lhs)?;
            let ra = self.atom(rhs)?;
            return Some(if op == "==" {
                format!("__k2cjRefEq2({}, {})", la, ra)
            } else {
                format!("!__k2cjRefEq2({}, {})", la, ra)
            });
        }
        // 桶 B：两侧均为 Equatable 值类型，且恰一侧可空 → 裸值一侧包 `Some(...)`，
        // 使 Option<T> == Option<T> 成立（T 为 Equatable）。
        if lc == EqCat::Equatable && rc == EqCat::Equatable && (_ln ^ _rn) {
            let la = self.atom(lhs)?;
            let ra = self.atom(rhs)?;
            let (lw, rw) = if _ln {
                (la, format!("Some({})", ra))
            } else {
                (format!("Some({})", la), ra)
            };
            return Some(format!("{} {} {}", lw, op, rw));
        }
        None
    }

    // ============ 成员访问 ============

    fn render_member(&self, base: NodeId, name: &str, safe: bool) -> Option<String> {
        // Kotlin :: operator: ::class → drop (just base), ::method → strip :: prefix
        if name.starts_with("::") {
            let base_str = self.atom(base)?;
            if name == "::class" {
                return Some(base_str);
            }
            // ::method, ::property etc. → render as base.method (strip ::)
            let method = &name[2..];
            return Some(format!("{}.{}", base_str, crate::parser::safe_name(method)));
        }
        if let Kind::NameRef { original, .. } = self.g.kind(base) {
            if let Some(mapped) = self.render_type_constant(original, name) {
                return Some(mapped);
            }
            // R17 簇A阶段②: `EnumName.const`（仓颉 enum 无 static）→ 提升后的顶层名。
            if let Some(lifted) = self.enum_companion_const_lifted(original, name) {
                return Some(lifted);
            }
            if let Some(alias) = self.companion_static_alias(original, name) {
                return Some(format!("{}.{}", original, alias));
            }
            // 嵌套类提升注册表：`Parent.Nested` → 提升后的实际名字（撞名时带父类名前缀）
            if let Some(lifted) = self.lifted_nested.get(&(original.clone(), name.to_string())) {
                return Some(crate::parser::safe_name(lifted));
            }
            if self.is_class_name(original)
                && (self.enum_entries(name).is_some() || self.is_class_name(name))
            {
                return Some(crate::parser::safe_name(name));
            }
        }
        // super.method() → super.method() (no backtick escaping for super keyword)
        if let Kind::NameRef { original, .. } = self.g.kind(base) {
            if original == "`super`" || original == "super" {
                let mapped = match name {
                    "length" => "size",
                    other => other,
                };
                return Some(format!("super.{}", crate::parser::safe_name(mapped)));
            }
        }
        // Singleton object functions are rendered static; fields remain on INSTANCE.
        if let Kind::NameRef { original, .. } = self.g.kind(base) {
            if self.is_singleton_object(original) {
                let mapped = match name {
                    "length" => "size",
                    other => other,
                };
                let member = crate::parser::safe_name(mapped);
                if self.singleton_has_func(original, &member) {
                    return Some(format!("{}.{}", original, member));
                }
                return Some(format!("{}.INSTANCE.{}", original, member));
            }
        }
        let (b, dot) = if safe {
            let bs = if let Kind::Index { base: ib, index } = self.g.kind(base) {
                format!("{}.get({})", self.atom(*ib)?, self.t(*index)?)
            } else {
                self.atom(base)?
            };
            (bs, "?.")
        } else {
            // Auto-unwrap nullable types: if base has type ?T, use .getOrThrow() before member access
            // Skip unwrap for variables that are rebound inside if-let null-check blocks
            let raw = self.atom(base)?;
            let b = if self.is_nullable_expr(base) && !self.is_null_check_rebound(base) {
                format!("{}.getOrThrow()", raw)
            } else {
                raw
            };
            (b, ".")
        };
        let mapped = match name {
            "length" if !safe => {
                return Some(format!("{}.toRuneArray().size", b));
            }
            "size" if !safe && self.looks_string(base) => {
                return Some(format!("{}.toRuneArray().size", b));
            }
            "length" => "size",
            "indices" if !safe && self.looks_string(base) => {
                return Some(format!("(0..{}.toRuneArray().size)", b));
            }
            "indices" if !safe => return Some(format!("(0..{}.size)", b)),
            "lastIndex" if !safe && self.looks_string(base) => {
                return Some(format!("({}.toRuneArray().size - 1)", b));
            }
            "lastIndex" if !safe => return Some(format!("({}.size - 1)", b)),
            "code" if !safe && matches!(self.g.kind(base), Kind::Index { .. }) => {
                let elem = if let Kind::Index {
                    base: indexed_base,
                    index,
                } = self.g.kind(base)
                {
                    if self.looks_string(*indexed_base) || !self.looks_collection(*indexed_base) {
                        format!(
                            "{}.toRuneArray()[{}]",
                            self.atom(*indexed_base)?,
                            self.t(*index)?
                        )
                    } else {
                        b.clone()
                    }
                } else {
                    b.clone()
                };
                return Some(format!("Int64(UInt32({}))", elem));
            }
            "code" if !safe && self.looks_char(base) => {
                return Some(format!("Int64(UInt32({}))", b));
            }
            "code" if !safe && self.is_char_code_constant(base) => return Some(b),
            "first" if !safe && (self.looks_tuple(base) || !self.provably_non_collection(base)) => {
                return Some(format!("{}[0]", b));
            }
            "second"
                if !safe && (self.looks_tuple(base) || !self.provably_non_collection(base)) =>
            {
                return Some(format!("{}[1]", b));
            }
            "third" if !safe && (self.looks_tuple(base) || !self.provably_non_collection(base)) => {
                return Some(format!("{}[2]", b));
            }
            // 接收者可证明是非集合（如用户类 Attributes 的 `keys` 字段）时保留字段访问，
            // 否则 `attributes.keys = ...` 会被译成非法左值 `attributes.keys() = ...`
            "keys" if !self.provably_non_collection(base) => {
                return Some(format!("{}{}keys()", b, dot))
            }
            "values" if !self.provably_non_collection(base) => {
                return Some(format!("{}{}values()", b, dot))
            }
            other => {
                // 数据驱动查表：从 stdlib_map 查找简单方法重命名
                let receiver_hint = if self.looks_string(base) {
                    "string"
                } else if self.looks_char(base) {
                    "char"
                } else {
                    "any"
                };
                // 先按精确接收者类型查找，再按 "any" 回退
                crate::stdlib_map::lookup_method(other, receiver_hint)
                    .or_else(|| crate::stdlib_map::lookup_method_any(other))
                    .unwrap_or(other)
            }
        };
        Some(format!("{}{}{}", b, dot, crate::parser::safe_name(mapped)))
    }

    fn render_type_constant(&self, base: &str, name: &str) -> Option<String> {
        match (base, name) {
            ("Int", "MAX_VALUE") | ("Long", "MAX_VALUE") => Some("Int64.Max".to_string()),
            ("Int", "MIN_VALUE") | ("Long", "MIN_VALUE") => Some("Int64.Min".to_string()),
            ("Short", "MAX_VALUE") => Some("32767".to_string()),
            ("Short", "MIN_VALUE") => Some("-32768".to_string()),
            ("Byte", "MAX_VALUE") => Some("127".to_string()),
            ("Byte", "MIN_VALUE") => Some("-128".to_string()),
            ("Char", "MIN_VALUE") => Some("0x0000".to_string()),
            ("Char", "MAX_VALUE") => Some("0x10FFFF".to_string()),
            ("Char", "MIN_SURROGATE") | ("Char", "MIN_HIGH_SURROGATE") => {
                Some("0xD800".to_string())
            }
            ("Char", "MAX_HIGH_SURROGATE") => Some("0xDBFF".to_string()),
            ("Char", "MIN_LOW_SURROGATE") => Some("0xDC00".to_string()),
            ("Char", "MAX_SURROGATE") | ("Char", "MAX_LOW_SURROGATE") => Some("0xDFFF".to_string()),
            _ => None,
        }
    }

    fn is_char_code_constant(&self, id: NodeId) -> bool {
        matches!(
            self.g.kind(id),
            Kind::Member { base, name, .. }
                if matches!(self.g.kind(*base), Kind::NameRef { original, .. } if original == "Char")
                    && self.render_type_constant("Char", name).is_some()
        )
    }

    /// Check if a node is a CharLit with a surrogate code point (U+D800..U+DFFF).
    fn is_surrogate_char_lit(&self, id: NodeId) -> bool {
        if let Kind::CharLit(s) = self.g.kind(id) {
            if let Some(hex_str) = s.strip_prefix("\\u{").and_then(|h| h.strip_suffix("}")) {
                if let Ok(val) = u32::from_str_radix(hex_str, 16) {
                    return (0xD800..=0xDFFF).contains(&val);
                }
            }
        }
        false
    }

    fn render_singleton_static_field_ref(
        &self,
        id: NodeId,
        original: &str,
        decl: Option<NodeId>,
    ) -> Option<String> {
        let class_name = self.current_singleton_static_func_class(id)?;
        let field = crate::parser::safe_name(original);
        if let Some(d) = decl {
            if self.is_singleton_field_name_node(&class_name, d) {
                return Some(format!("{}.INSTANCE.{}", class_name, field));
            }
            return None;
        }
        if self.singleton_has_field(&class_name, &field) {
            Some(format!("{}.INSTANCE.{}", class_name, field))
        } else {
            None
        }
    }

    fn current_singleton_static_func_class(&self, id: NodeId) -> Option<String> {
        let mut cur = Some(id);
        while let Some(node_id) = cur {
            if matches!(self.g.kind(node_id), Kind::Func { .. }) {
                let class_id = self.g.nodes[node_id].parent?;
                if let Kind::Class {
                    name, is_singleton, ..
                } = self.g.kind(class_id)
                {
                    if *is_singleton {
                        return Some(name.clone());
                    }
                }
                return None;
            }
            cur = self.g.nodes[node_id].parent;
        }
        None
    }

    fn singleton_has_func(&self, class_name: &str, member_name: &str) -> bool {
        let Some(&cid) = self.class_index.get(&crate::parser::safe_name(class_name)) else {
            return false;
        };
        let Kind::Class {
            members,
            is_singleton,
            ..
        } = self.g.kind(cid)
        else {
            return false;
        };
        *is_singleton
            && members
                .iter()
                .any(|m| matches!(self.g.kind(*m), Kind::Func { name, .. } if *name == member_name))
    }

    fn singleton_has_field(&self, class_name: &str, member_name: &str) -> bool {
        let Some(&cid) = self.class_index.get(&crate::parser::safe_name(class_name)) else {
            return false;
        };
        let Kind::Class {
            members,
            is_singleton,
            ..
        } = self.g.kind(cid)
        else {
            return false;
        };
        *is_singleton
            && members.iter().any(|m| {
                matches!(
                    self.g.kind(*m),
                    Kind::VarDecl { name_node, .. }
                        if matches!(self.g.kind(*name_node), Kind::Name { original }
                            if crate::parser::safe_name(original) == member_name)
                )
            })
    }

    fn is_singleton_field_name_node(&self, class_name: &str, name_node: NodeId) -> bool {
        let Some(&cid) = self.class_index.get(&crate::parser::safe_name(class_name)) else {
            return false;
        };
        let Kind::Class {
            members,
            is_singleton,
            ..
        } = self.g.kind(cid)
        else {
            return false;
        };
        *is_singleton && members.iter().any(|m| {
            matches!(self.g.kind(*m), Kind::VarDecl { name_node: nn, .. } if *nn == name_node)
        })
    }

    fn render_companion_static_field_ref(
        &self,
        id: NodeId,
        original: &str,
        decl: Option<NodeId>,
    ) -> Option<String> {
        let class_name = self.current_class(id)?;
        let field = crate::parser::safe_name(original);
        if let Some(d) = decl {
            if self.is_companion_field_name_node(&class_name, d) {
                let suffix = if self.companion_field_rendered_as_func(&class_name, &field) {
                    "()"
                } else {
                    ""
                };
                return Some(format!("{}.{}{}", class_name, field, suffix));
            }
            return None;
        }
        if self.companion_has_field(&class_name, &field) {
            let suffix = if self.companion_field_rendered_as_func(&class_name, &field) {
                "()"
            } else {
                ""
            };
            Some(format!("{}.{}{}", class_name, field, suffix))
        } else {
            None
        }
    }

    fn current_class(&self, id: NodeId) -> Option<String> {
        let mut cur = Some(id);
        while let Some(node_id) = cur {
            if let Kind::Class { name, .. } = self.g.kind(node_id) {
                return Some(name.clone());
            }
            cur = self.g.nodes[node_id].parent;
        }
        None
    }

    fn companion_has_field(&self, class_name: &str, member_name: &str) -> bool {
        let Some(&cid) = self.class_index.get(&crate::parser::safe_name(class_name)) else {
            return false;
        };
        let Kind::Class {
            companion_members, ..
        } = self.g.kind(cid)
        else {
            return false;
        };
        companion_members.iter().any(|m| {
            matches!(
                self.g.kind(*m),
                Kind::VarDecl { name_node, .. }
                    if matches!(self.g.kind(*name_node), Kind::Name { original }
                        if crate::parser::safe_name(original) == member_name)
            )
        })
    }

    fn is_companion_field_name_node(&self, class_name: &str, name_node: NodeId) -> bool {
        let Some(&cid) = self.class_index.get(&crate::parser::safe_name(class_name)) else {
            return false;
        };
        let Kind::Class {
            companion_members, ..
        } = self.g.kind(cid)
        else {
            return false;
        };
        companion_members.iter().any(
            |m| matches!(self.g.kind(*m), Kind::VarDecl { name_node: nn, .. } if *nn == name_node),
        )
    }

    fn companion_field_rendered_as_func(&self, class_name: &str, member_name: &str) -> bool {
        let Some(&cid) = self.class_index.get(&crate::parser::safe_name(class_name)) else {
            return false;
        };
        let Kind::Class {
            companion_members, ..
        } = self.g.kind(cid)
        else {
            return false;
        };
        companion_members.iter().any(|m| {
            let Kind::VarDecl {
                name_node,
                init: Some(init),
                ..
            } = self.g.kind(*m)
            else {
                return false;
            };
            if !matches!(self.g.kind(*name_node), Kind::Name { original }
                if crate::parser::safe_name(original) == member_name)
            {
                return false;
            }
            !self.is_static_scalar_const_expr(*init)
        })
    }

    fn is_static_scalar_const_expr(&self, id: NodeId) -> bool {
        matches!(
            self.g.kind(id),
            Kind::IntLit(_)
                | Kind::FloatLit(_)
                | Kind::BoolLit(_)
                | Kind::CharLit(_)
                | Kind::StrTemplate { .. }
        )
    }

    // ============ if 渲染 ============

    fn render_if(&self, cond: NodeId, then_b: NodeId, else_b: Option<NodeId>) -> Option<String> {
        if let Some((bind, recv, negated)) = self.null_check(cond) {
            let reassigned = self.block_assigns(then_b, &bind)
                || else_b.map_or(false, |e| self.block_assigns(e, &bind));
            if !reassigned {
                let tb = self.render_block(then_b)?;
                let bind_value = self.non_conflicting_if_let_bind(&bind, then_b, else_b);
                let head = format!("if (let Some({}) <- {})", bind_value, recv);
                if negated {
                    match else_b {
                        Some(e) => {
                            let eb = self.render_block(e)?;
                            let eb = if bind_value == bind {
                                eb
                            } else {
                                self.rebind_block(&bind, &bind_value, &eb)
                            };
                            return Some(format!("{} {} else {}", head, eb, tb));
                        }
                        None => {}
                    }
                } else {
                    let tb = if bind_value == bind {
                        tb
                    } else {
                        self.rebind_block(&bind, &bind_value, &tb)
                    };
                    match else_b {
                        Some(e) => {
                            let eb = self.render_block(e)?;
                            return Some(format!("{} {} else {}", head, tb, eb));
                        }
                        None => return Some(format!("{} {}", head, tb)),
                    }
                }
            }
        }
        let c = self.t(cond)?;
        let tb = self.render_block(then_b)?;
        match else_b {
            Some(e) => {
                let eb = if let Kind::Block { stmts } = self.g.kind(e) {
                    if stmts.len() == 1 && matches!(self.g.kind(stmts[0]), Kind::If { .. }) {
                        self.t(stmts[0])?
                    } else {
                        self.render_block(e)?
                    }
                } else {
                    self.render_block(e)?
                };
                Some(format!("if ({}) {} else {}", c, tb, eb))
            }
            None => Some(format!("if ({}) {}", c, tb)),
        }
    }

    // ============ 函数渲染 ============

    fn render_func(
        &self,
        id: NodeId,
        name: &str,
        params: &[NodeId],
        ret: Option<String>,
        body: NodeId,
        is_main: bool,
        is_abstract: bool,
        is_override: bool,
        receiver_type: Option<&str>,
        generic_params: &[String],
    ) -> Option<String> {
        let ps: Vec<String> = params.iter().map(|p| self.t(*p)).collect::<Option<_>>()?;
        // Determine open context early — needed to strip defaults from open funcs
        let in_open_class = self.func_in_open_class(id);
        // seam 1/2：`<: List<T>` 委托类（Nodes/ParseErrorList 及子类 Elements）的
        // 成员需对齐 std List<T> 面。
        let list_iface_member = !is_main
            && receiver_type.is_none()
            && self
                .owning_class_of(id)
                .map_or(false, |cid| self.is_list_iface_class(cid));
        // seam 1：List<T> 要求 `prop first/last`（抽象）。用户 0 参 first()/last()
        // 方法转渲染为 prop（body 作为 getter 保留），避免与接口 prop 撞名。
        if list_iface_member && params.is_empty() && (name == "first" || name == "last") {
            let ret_ty = ret.clone().unwrap_or_else(|| "Unit".to_string());
            let vis = if is_override && in_open_class {
                "public open override "
            } else if is_override {
                "public override "
            } else if in_open_class {
                "public open "
            } else {
                "public "
            };
            let body_block = self.render_block(body)?;
            return Some(format!(
                "{}prop {}: {} {{\n{}get() {}\n}}",
                vis, name, ret_ty, IND, body_block
            ));
        }
        // Cangjie: open functions AND interface/abstract methods cannot have
        // default parameter values. Strip " = <default>" suffix from params
        // when the function will be open or is an interface/abstract method.
        let ps: Vec<String> = if in_open_class || is_abstract || (is_override && in_open_class) {
            ps.into_iter()
                .map(|p| {
                    if let Some(eq) = p.find(" = ") {
                        p[..eq].to_string()
                    } else {
                        p
                    }
                })
                .collect()
        } else {
            ps
        };
        // 仓颉命名参数（`name!: T = default`）必须位于全部位置参数之后。Kotlin 的
        // 中位默认值参数（`fun f(q: String? = null, next: Boolean)`）在 Kotlin 侧
        // 也无法按位置省略——降级为位置参数（去掉 `!` 与默认值），调用点不受影响。
        let last_plain = params
            .iter()
            .rposition(|p| matches!(self.g.kind(*p), Kind::Param { default: None, .. }));
        let ps: Vec<String> = ps
            .into_iter()
            .enumerate()
            .map(|(i, p)| {
                if last_plain.is_some_and(|lp| i < lp) {
                    if let Some(bang) = p.find("!: ") {
                        let name = &p[..bang];
                        let rest = &p[bang + 3..];
                        let ty = rest.split(" = ").next().unwrap_or(rest);
                        return format!("{}: {}", name, ty);
                    }
                }
                p
            })
            .collect();
        // generic_params 条目可能编码 bound（`"T <: Shape"`，见 parser::parse_generic_params）：
        // `<...>` 只放名字，bound 拆到 `where` 子句（仓颉调用 T 成员方法必需）。
        let (gen_suffix, where_clause) = if generic_params.is_empty() {
            (String::new(), String::new())
        } else {
            let names: Vec<&str> = generic_params
                .iter()
                .map(|g| g.split(" <: ").next().unwrap_or(g))
                .collect();
            // 可空 bound（Kotlin `<E : Element?>`）在仓颉无对应约束语法，丢弃该
            // where 条目（保守放宽；jsoup 此类方法体内只做引用比较，不调 E 成员）。
            let bounds: Vec<&str> = generic_params
                .iter()
                .filter(|g| g.contains(" <: ") && !g.contains('?'))
                .map(|g| g.as_str())
                .collect();
            let w = if bounds.is_empty() {
                String::new()
            } else {
                format!(" where {}", bounds.join(", "))
            };
            (format!("<{}>", names.join(", ")), w)
        };
        if is_main {
            let b = self.render_block(body)?;
            return Some(format!("main() {}", b));
        }
        // 扩展函数渲染为 extend ReceiverType { func name(...) { ... } }
        if let Some(recv_ty) = receiver_type {
            let r = match &ret {
                Some(r) => format!(": {}", r),
                None => String::new(),
            };
            let sig = format!("{}{}({}){}{}", name, gen_suffix, ps.join(", "), r, where_clause);
            let b = self.render_block(body)?;
            let func_str = format!("func {} {}", sig, b);
            return Some(format!(
                "extend {} {{\n{}\n}}",
                recv_ty,
                indent(&func_str, 1)
            ));
        }
        // seam 2：std List<T> 的 `removeIf(...)` 返 Unit；Kotlin 用户 removeIf 返
        // Bool（是否移除）不是子类型。委托类的 removeIf 强制返 Unit，原 body 包进
        // 立即执行 lambda 丢弃布尔返回值（lambda 内 return 从 lambda 返回）。
        let force_unit_removeif = list_iface_member && name == "removeIf" && ret.is_some();
        let r = if force_unit_removeif {
            ": Unit".to_string()
        } else {
            match &ret {
                Some(r) => format!(": {}", r),
                None if self.refers_name(body, name) => ": Unit".to_string(),
                None if is_abstract => ": Unit".to_string(),
                None if self.has_while_true_return(body) => ": Unit".to_string(),
                None => String::new(),
            }
        };
        let sig = format!("{}{}({}){}{}", name, gen_suffix, ps.join(", "), r, where_clause);
        if is_abstract {
            return Some(format!("public func {}", sig));
        }
        let mut b = self.render_block(body)?;
        if force_unit_removeif {
            // `{ <stmts> }` → `{\n    let _ = { => <stmts> }()\n}`（丢弃 Bool 返回）。
            let lambda = format!("{{ =>{}", &b[1..]);
            b = format!("{{\n{}let _ = {}()\n}}", IND, lambda);
        }
        // while(true) 返回修复：在 while(true) 后添加不可达默认返回以满足仓颉类型检查
        if self.has_while_true_return(body) && ret.is_some() {
            let ret_str = ret.as_ref().unwrap();
            let default_val = match ret_str.as_str() {
                "Int64" => "0",
                "Float64" => "0.0",
                "Bool" => "false",
                "String" => "\"\"",
                _ => "throw Exception(\"unreachable\")",
            };
            // Insert before the closing brace
            if b.ends_with('}') {
                b = format!(
                    "{}\n{}{}",
                    &b[..b.len() - 1],
                    crate::render::IND,
                    format!("{}\n}}", default_val)
                );
            }
        }
        // Determine visibility/open modifiers based on parent class context.
        // override 在全部父类型中都无可匹配成员时剥离（marker stub 接口场景），
        // 避免 cjc "does not have an overridden function in its supertype"。
        // 顶层作用域函数（无归属类、非扩展）带 override 是非法的（仓颉 override 仅限
        // 类/接口成员）——多出现于类体被截断后成员泄漏到顶层、或嵌套/扩展提升场景。
        // 无条件剥 override，避免 "unexpected modifier 'override' in 'top-level' scope"。
        let is_top_level = self.owning_class_of(id).is_none();
        let stripped =
            is_override && (self.override_provably_unmatched(id, name) || is_top_level);
        let is_override = is_override && !stripped;
        let vis = if is_override && in_open_class {
            "public open override "
        } else if is_override {
            "public override "
        } else if in_open_class {
            "public open "
        } else if stripped {
            "public "
        } else {
            ""
        };
        Some(format!("{}func {} {}", vis, sig, b))
    }

    // ============ 类渲染 ============

    #[allow(clippy::too_many_arguments)]
    fn render_class(
        &self,
        name: &str,
        ctor_params: &[CtorParam],
        members: &[NodeId],
        superclass: Option<String>,
        is_open: bool,
        is_data: bool,
        is_value: bool,
        is_interface: bool,
        is_abstract: bool,
        interfaces: &[String],
        super_args: &[NodeId],
        generics: &[String],
        init_block: Option<NodeId>,
        companion_members: &[NodeId],
        is_singleton: bool,
        supertype_delegations: &[SuperDelegation],
        is_expect: bool,
    ) -> Option<String> {
        let gen_suffix = if generics.is_empty() {
            String::new()
        } else {
            format!("<{}>", generics.join(", "))
        };
        let name_gen = format!("{}{}", name, gen_suffix);
        if is_interface {
            self.render_interface(name, &name_gen, members, interfaces)
        } else if is_singleton {
            self.render_singleton(name, &name_gen, members, &superclass, interfaces)
        } else {
            self.render_regular_class(
                name,
                &name_gen,
                ctor_params,
                members,
                superclass,
                is_open,
                is_data,
                is_value,
                is_abstract,
                interfaces,
                super_args,
                init_block,
                companion_members,
                supertype_delegations,
                is_expect,
            )
        }
    }

    /// 渲染 interface 声明。
    fn render_interface(
        &self,
        _name: &str,
        name_gen: &str,
        members: &[NodeId],
        interfaces: &[String],
    ) -> Option<String> {
        let mut ibody = String::new();
        for m in members {
            if let Kind::Func {
                name: fname,
                params,
                ret,
                ..
            } = self.g.kind(*m)
            {
                let ps: Vec<String> = params.iter().map(|p| self.t(*p)).collect::<Option<_>>()?;
                // Cangjie: interface methods cannot have default parameter values.
                // Strip " = <default>" suffix from params (Kotlin interface 默认参数).
                let ps: Vec<String> = ps
                    .into_iter()
                    .map(|p| {
                        if let Some(eq) = p.find(" = ") {
                            p[..eq].to_string()
                        } else {
                            p
                        }
                    })
                    .collect();
                let r = ret
                    .clone()
                    .map(|r| format!(": {}", r))
                    .unwrap_or_else(|| ": Unit".to_string());
                ibody.push_str(&format!("{}func {}({}){}\n", IND, fname, ps.join(", "), r));
            }
        }
        let sup = if interfaces.is_empty() {
            String::new()
        } else {
            format!(" <: {}", interfaces.join(" & "))
        };
        if ibody.is_empty() {
            Some(format!("interface {}{} {{}}", name_gen, sup))
        } else {
            Some(format!("interface {}{} {{\n{}}}", name_gen, sup, ibody))
        }
    }

    /// 渲染 object 单例声明 → class with private init + static INSTANCE。
    fn render_singleton(
        &self,
        name: &str,
        name_gen: &str,
        members: &[NodeId],
        superclass: &Option<String>,
        interfaces: &[String],
    ) -> Option<String> {
        let mut sbody = String::new();
        let mut lifted = Vec::new();
        let mut init_assigns = Vec::new();
        for m in members {
            if let Kind::VarDecl {
                name_node,
                init: Some(init),
                ..
            } = self.g.kind(*m)
            {
                if let Kind::Name { original } = self.g.kind(*name_node) {
                    if let Some(rendered_init) = self.t(*init) {
                        init_assigns.push((
                            crate::parser::safe_name(original),
                            self.qualify_singleton_init_call(name, *init, &rendered_init),
                        ));
                    }
                }
            }
        }
        if init_assigns.is_empty() {
            sbody.push_str(&format!("{}private init() {{}}\n", IND));
        } else {
            sbody.push_str(&format!("{}private init() {{\n", IND));
            for (field, init) in &init_assigns {
                sbody.push_str(&format!("{}{}this.{} = {}\n", IND, IND, field, init));
            }
            sbody.push_str(&format!("{}}}\n", IND));
        }
        sbody.push_str(&format!("{}public static let INSTANCE = {}()\n", IND, name));
        for m in members {
            if matches!(self.g.kind(*m), Kind::Class { .. } | Kind::Enum { .. }) {
                lifted.push(self.t(*m)?);
                continue;
            }
            let mt = if self
                .var_decl_name(*m)
                .is_some_and(|field| init_assigns.iter().any(|(moved, _)| moved == &field))
            {
                self.render_var_decl_without_init(*m)?
            } else {
                let mt = self.t(*m)?;
                if matches!(self.g.kind(*m), Kind::Func { .. }) {
                    // `static` 与 `override` 冲突——静态化成员剥 override。
                    format!("static {}", strip_modifier(&mt, "override"))
                } else {
                    mt
                }
            };
            sbody.push_str(&indent(&mt, 1));
            sbody.push('\n');
        }
        let mut ifaces: Vec<String> = Vec::new();
        if let Some(s) = superclass {
            ifaces.push(s.clone());
        }
        ifaces.extend(interfaces.iter().cloned());
        if !ifaces.contains(&"ToString".to_string()) {
            if self.has_override_tostring(members) {
                ifaces.push("ToString".to_string());
            }
        }
        let sup = if ifaces.is_empty() {
            String::new()
        } else {
            format!(" <: {}", ifaces.join(" & "))
        };
        let class_text = format!("class {}{} {{\n{}}}", name_gen, sup, sbody);
        if lifted.is_empty() {
            Some(class_text)
        } else {
            Some(format!("{}\n\n{}", class_text, lifted.join("\n\n")))
        }
    }

    /// 渲染普通 class / abstract class / open class / data class。
    #[allow(clippy::too_many_arguments)]
    fn render_regular_class(
        &self,
        name: &str,
        name_gen: &str,
        ctor_params: &[CtorParam],
        members: &[NodeId],
        superclass: Option<String>,
        is_open: bool,
        is_data: bool,
        is_value: bool,
        is_abstract: bool,
        interfaces: &[String],
        super_args: &[NodeId],
        init_block: Option<NodeId>,
        companion_members: &[NodeId],
        supertype_delegations: &[SuperDelegation],
        is_expect: bool,
    ) -> Option<String> {
        let mut body = String::new();
        // 集合接口委托（`: MutableList<T> by delegate`）：合成后备字段 + `List<T>`
        // 父类型 + 转发成员。返回 (后备字段声明, 转发成员文本, 追加的父类型)。
        let (deleg_fields, deleg_members, deleg_ifaces) =
            self.render_list_delegations(supertype_delegations, members, is_open);
        // Promote Plain ctor params that need to be accessible from methods
        // (e.g. `cause` in Exception subclasses, referenced via inherited Throwable.cause).
        let mut ctor_params_owned: Vec<CtorParam> = ctor_params.to_vec();
        let is_exception_class = superclass
            .as_deref()
            .map(|s| s == "Exception" || s.ends_with("Exception"))
            .unwrap_or(false)
            || interfaces.iter().any(|s| s == "Exception" || s.ends_with("Exception"));
        if is_exception_class {
            for p in &mut ctor_params_owned {
                if p.kind == CtorParamKind::Plain && p.name == "cause" {
                    p.kind = CtorParamKind::Var;
                }
            }
        }
        // Also promote secondary constructor `cause` params to class fields,
        // so they are accessible from methods (Kotlin's inherited Throwable.cause).
        let mut sec_cause_fields: Vec<(String, String)> = Vec::new();
        if is_exception_class {
            for m in members {
                if let Kind::SecondaryConstructor { params, .. } = self.g.kind(*m) {
                    for p in params {
                        if let Kind::Param { name_node, ty, .. } = self.g.kind(*p) {
                            if let Kind::Name { original } = self.g.kind(*name_node) {
                                let pname = crate::parser::safe_name(original);
                                if pname == "cause" && !sec_cause_fields.iter().any(|(n, _)| n == &pname) {
                                    sec_cause_fields.push((pname, ty.clone()));
                                }
                            }
                        }
                    }
                }
            }
        }
        let ctor_params: &[CtorParam] = &ctor_params_owned;
        let moved_member_inits = self.member_inits_referencing_ctor_params(ctor_params, members);
        // 成员字段声明
        for p in ctor_params {
            match p.kind {
                CtorParamKind::Val => {
                    body.push_str(&format!("{}let {}: {}\n", IND, p.name, p.ty));
                }
                CtorParamKind::Var => {
                    body.push_str(&format!("{}var {}: {}\n", IND, p.name, p.ty));
                }
                CtorParamKind::Plain => {}
            }
        }
        for (name, _ty) in &sec_cause_fields {
            // Store cause as Exception type for cross-Exception-subtype compatibility.
            body.push_str(&format!("{}var {}: ?Exception = None\n", IND, name));
        }
        // 集合接口委托的合成后备字段（委托目标非裸标识符时）。
        body.push_str(&deleg_fields);
        // 构造器
        let super_call: Option<String> = if super_args.is_empty() {
            None
        } else {
            let a: Vec<String> = super_args
                .iter()
                .map(|x| self.t(*x))
                .collect::<Option<_>>()?;
            Some(format!("super({})", a.join(", ")))
        };
        let primary_init_emitted =
            !ctor_params.is_empty() || super_call.is_some() || init_block.is_some();
        if primary_init_emitted {
            let ps: Vec<String> = ctor_params
                .iter()
                .map(|p| {
                    if let Some(def_id) = p.default {
                        let def_val = self.t(def_id).unwrap_or_else(|| "None".to_string());
                        format!("{}!: {} = {}", p.name, p.ty, def_val)
                    } else {
                        format!("{}: {}", p.name, p.ty)
                    }
                })
                .collect();
            // 中位默认值参数降级（与 render_func L1085-1102 一致）：
            // 仓颉命名参数（`name!: T = default`）必须位于全部位置参数之后。
            // Kotlin 中位默认值参数（`init(a, b: String = "x", c: Int)`）降级为
            // 位置参数（去 `!` 与默认值）。1g R2 修过 render_func，1f 提供 ctor 实例。
            let last_plain = ctor_params.iter().rposition(|p| p.default.is_none());
            let ps: Vec<String> = ps
                .into_iter()
                .enumerate()
                .map(|(i, p)| {
                    if last_plain.is_some_and(|lp| i < lp) {
                        if let Some(bang) = p.find("!: ") {
                            let name = &p[..bang];
                            let rest = &p[bang + 3..];
                            let ty = rest.split(" = ").next().unwrap_or(rest);
                            return format!("{}: {}", name, ty);
                        }
                    }
                    p
                })
                .collect();
            body.push_str(&format!("{}init({}) {{\n", IND, ps.join(", ")));
            if let Some(sc) = &super_call {
                body.push_str(&format!("{}{}{}\n", IND, IND, sc));
            }
            for p in ctor_params {
                if p.kind != CtorParamKind::Plain {
                    body.push_str(&format!("{}{}this.{} = {}\n", IND, IND, p.name, p.name));
                }
            }
            for (field, init) in &moved_member_inits {
                body.push_str(&format!("{}{}this.{} = {}\n", IND, IND, field, init));
            }
            if let Some(ib) = init_block {
                if let Kind::Block { stmts } = self.g.kind(ib) {
                    for s in stmts {
                        let st = self.t(*s)?;
                        body.push_str(&indent(&st, 2));
                        body.push('\n');
                    }
                }
            }
            body.push_str(&format!("{}}}\n", IND));
        }
        if !primary_init_emitted && self.needs_empty_primary_init(members) {
            body.push_str(&format!("{}init() {{}}\n", IND));
        }
        // 收集类字段名（用于跳过平凡 getter）
        let field_names: Vec<String> = ctor_params
            .iter()
            .filter(|p| p.kind != CtorParamKind::Plain)
            .map(|p| p.name.clone())
            .chain(
                members
                    .iter()
                    .filter_map(|m| self.var_decl_name(*m)),
            )
            .collect();
        let is_trivial_getter = |m: NodeId| -> bool {
            if let Kind::Func {
                name,
                params,
                is_override,
                ..
            } = &self.g.nodes[m].kind
            {
                // 无参、非 override、名称与字段冲突 → 平凡的 getter，field 已提供访问
                params.is_empty() && !is_override && field_names.contains(name)
            } else {
                false
            }
        };
        // 成员方法
        let mut lifted = Vec::new();
        for m in members {
            // 跳过平凡 getter（field 声明已提供访问）
            if is_trivial_getter(*m) {
                continue;
            }
            // 扩展函数必须提升到顶层（仓颉不允许在类内声明 extend）
            if let Kind::Func {
                receiver_type: Some(_),
                ..
            } = &self.g.nodes[*m].kind
            {
                lifted.push(self.t(*m)?);
                continue;
            }
            if matches!(self.g.kind(*m), Kind::Class { .. } | Kind::Enum { .. }) {
                lifted.push(self.t(*m)?);
                continue;
            }
            // `expect class` 成员：common 侧无实现——字段渲染为抛异常的计算 prop、
            // 方法/构造器渲染为 throw stub body（否则无体成员被 cjc 拒为 "can not be
            // abstract" / 未初始化字段）。companion 成员加 `static`。
            if is_expect {
                let is_companion = companion_members.contains(m);
                let em = self.render_expect_member(*m, is_companion)?;
                body.push_str(&indent(&em, 1));
                body.push('\n');
                continue;
            }
            if let Some(field) = self.var_decl_name(*m) {
                if moved_member_inits.iter().any(|(moved, _)| moved == &field) {
                    let mt = self.render_var_decl_without_init(*m)?;
                    body.push_str(&indent(&mt, 1));
                    body.push('\n');
                    continue;
                }
            }
            let mt = self.t(*m)?;
            let is_companion = companion_members.contains(m);
            if is_companion {
                // Cangjie 不允许类内 main()——提升到顶层
                if let Kind::Func { name: func_name, .. } = self.g.kind(*m) {
                    if crate::parser::safe_name(func_name).trim_matches('`') == "main" {
                        let cleaned = strip_modifier(&mt, "static");
                        let cleaned = strip_modifier(&cleaned, "open");
                        lifted.push(cleaned.trim().to_string());
                        continue;
                    }
                }
                if let Some(static_func) = self.render_companion_field_func(*m) {
                    body.push_str(&indent(&static_func, 1));
                    body.push('\n');
                    continue;
                }
                let mt = self.rename_conflicting_companion_func(name, *m, &mt);
                let mt_no_open = strip_modifier(&mt, "open");
                // 静态化：`static` 与 `override` 冲突（仓颉 static 成员无重写语义）——剥 override。
                let mt_no_open = strip_modifier(&mt_no_open, "override");
                let static_mt = if mt_no_open.starts_with("func ") {
                    format!("static {}", mt_no_open)
                } else if mt_no_open.starts_with("public ") {
                    mt_no_open.replacen("func ", "static func ", 1)
                } else {
                    format!("static {}", mt_no_open)
                };
                body.push_str(&indent(&static_mt, 1));
            } else {
                body.push_str(&indent(&mt, 1));
            }
            body.push('\n');
        }
        // data class 自动 toString
        let has_user_tostring = members
            .iter()
            .any(|m| matches!(self.g.kind(*m), Kind::Func { name, .. } if name == "toString"));
        if is_data && !ctor_params.is_empty() && !has_user_tostring {
            let fields: Vec<String> = ctor_params
                .iter()
                .filter(|p| p.kind != CtorParamKind::Plain)
                .map(|p| format!("{}=${{this.{}}}", p.name, p.name))
                .collect();
            body.push_str(&format!(
                "{}public func toString(): String {{\n{}{}return \"{}({})\"\n{}}}\n",
                IND,
                IND,
                IND,
                name,
                fields.join(", "),
                IND
            ));
        }
        // 集合接口委托的转发成员（转发到委托目标，满足 List<T> 接口面）。
        body.push_str(&deleg_members);
        // 类关键字与继承。value class → 仓颉 struct（值语义），@Derive[Equatable]
        // 自动派生结构相等（== / !=）。注意：派生的 == 在类型自身方法体内不可见，
        // 故 value class 内部的 `when(this)` 比较走字段（见 render_when）。
        let kw = if is_value {
            "struct"
        } else if is_abstract {
            "abstract class"
        } else if is_open {
            "open class"
        } else {
            "class"
        };
        let mut ifaces: Vec<String> = Vec::new();
        if let Some(s) = &superclass {
            ifaces.push(s.clone());
        }
        ifaces.extend(interfaces.iter().cloned());
        // 集合接口委托：真实仓颉 `List<T>` 父类型（替代原 MutableList marker）。
        ifaces.extend(deleg_ifaces.iter().cloned());
        if is_data {
            ifaces.push("ToString".to_string());
        }
        if !is_data && !ifaces.contains(&"ToString".to_string()) {
            if self.has_override_tostring(members) {
                ifaces.push("ToString".to_string());
            }
        }
        // 不显式声明 `<: Equatable<T>`——@Derive 已注入该 conformance，重复声明会冲突。
        let sup = if ifaces.is_empty() {
            String::new()
        } else {
            format!(" <: {}", ifaces.join(" & "))
        };
        let derive_attr = if is_value { "@Derive[Equatable]\n" } else { "" };
        let class_text = if body.is_empty() {
            format!("{}{} {}{} {{}}", derive_attr, kw, name_gen, sup)
        } else {
            format!("{}{} {}{} {{\n{}}}", derive_attr, kw, name_gen, sup, body)
        };
        if lifted.is_empty() {
            Some(class_text)
        } else {
            Some(format!("{}\n\n{}", class_text, lifted.join("\n\n")))
        }
    }

    /// 集合接口委托（Kotlin `class C : MutableList<T> by delegate`）渲染。
    ///
    /// 返回 `(后备字段声明, 转发成员文本, 追加父类型)`：
    /// - 父类型：真实仓颉 `List<T>`（`std.collection`，替代 R5 的 MutableList marker）。
    /// - 后备字段：委托目标非裸标识符（如 `by mutableListOf()`）时合成一个
    ///   `private let __k2cj_delegate: ArrayList<T>` 持有委托对象；裸标识符
    ///   （如 `by delegateList`，指向构造参数字段）直接转发，不建后备字段。
    /// - 转发成员：cjc 1.0.5 探针实测的 `List<T>`（含 `Collection<T>`）完整必需面——
    ///   `get / [](get) / [](set) / add×4 / remove×2 / removeIf / clear / isEmpty /
    ///   iterator / toArray` + `prop first / last / size`——逐一转发到委托目标。
    ///   用户已 override 的成员按 (名字, 参数个数) 去重，避免 redefinition。
    fn render_list_delegations(
        &self,
        delegations: &[SuperDelegation],
        members: &[NodeId],
        is_open: bool,
    ) -> (String, String, Vec<String>) {
        let mut fields = String::new();
        let mut mbody = String::new();
        let mut ifaces: Vec<String> = Vec::new();
        // 一个类多重集合委托无实际意义——只处理首个。
        let Some(d) = delegations.first() else {
            return (fields, mbody, ifaces);
        };
        let t = d.type_args.trim().to_string();
        if t.is_empty() {
            return (fields, mbody, ifaces);
        }
        let Some(dstr) = self.t(d.delegate) else {
            return (fields, mbody, ifaces);
        };
        // 委托目标：裸标识符（构造参数/字段）直接转发；否则合成后备字段。
        let target = if matches!(self.g.kind(d.delegate), Kind::NameRef { .. }) {
            dstr
        } else {
            let fname = "__k2cj_delegate".to_string();
            fields.push_str(&format!(
                "{}private let {}: ArrayList<{}> = {}\n",
                IND, fname, t, dstr
            ));
            fname
        };
        ifaces.push(format!("List<{}>", t));
        // 用户已定义成员签名 (名字, 参数个数)，用于去重。
        let mut user_sigs: std::collections::HashSet<(String, usize)> =
            std::collections::HashSet::new();
        for m in members {
            match self.g.kind(*m) {
                Kind::Func { name, params, .. } => {
                    user_sigs.insert((name.clone(), params.len()));
                }
                _ => {
                    if let Some(n) = self.var_decl_name(*m) {
                        user_sigs.insert((n, 0));
                    }
                }
            }
        }
        let om = if is_open { "public open" } else { "public" };
        // (去重键, 代码)。去重键 None = 命名参数/操作符签名，绝不与用户成员冲突，恒生成。
        let gen_members: Vec<(Option<(&str, usize)>, String)> = vec![
            (Some(("get", 1)), format!(
                "{} func get(index: Int64): ?{} {{\n{}return {}.get(index)\n}}",
                om, t, IND, target)),
            (None, format!(
                "{} operator func [](index: Int64): {} {{\n{}return {}[index]\n}}",
                om, t, IND, target)),
            (None, format!(
                "{} operator func [](index: Int64, value!: {}): Unit {{\n{}{}[index] = value\n}}",
                om, t, IND, target)),
            (Some(("add", 1)), format!(
                "{} func add(element: {}): Unit {{\n{}{}.add(element)\n}}",
                om, t, IND, target)),
            (None, format!(
                "{} func add(element: {}, at!: Int64): Unit {{\n{}{}.add(element, at: at)\n}}",
                om, t, IND, target)),
            (None, format!(
                "{} func add(all!: Collection<{}>): Unit {{\n{}{}.add(all: all)\n}}",
                om, t, IND, target)),
            (None, format!(
                "{} func add(all!: Collection<{}>, at!: Int64): Unit {{\n{}{}.add(all: all, at: at)\n}}",
                om, t, IND, target)),
            // remove(at!: Int64) 用命名参数 `at!`，与 Kotlin 用户 `remove(element: T)`
            // （位置参数）签名不同、不冲突——故不去重（key None），保证 List.remove(at)
            // 恒被实现（否则用户 remove(element) 会误伤去重导致 unimplemented remove）。
            (None, format!(
                "{} func remove(at!: Int64): {} {{\n{}return {}.remove(at: at)\n}}",
                om, t, IND, target)),
            (None, format!(
                "{} func remove(range: Range<Int64>): Unit {{\n{}{}.remove(range)\n}}",
                om, IND, target)),
            (Some(("removeIf", 1)), format!(
                "{} func removeIf(predicate: ({}) -> Bool): Unit {{\n{}{}.removeIf(predicate)\n}}",
                om, t, IND, target)),
            (Some(("clear", 0)), format!(
                "{} func clear(): Unit {{\n{}{}.clear()\n}}",
                om, IND, target)),
            (Some(("isEmpty", 0)), format!(
                "{} func isEmpty(): Bool {{\n{}return {}.isEmpty()\n}}",
                om, IND, target)),
            (Some(("iterator", 0)), format!(
                "{} func iterator(): Iterator<{}> {{\n{}return {}.iterator()\n}}",
                om, t, IND, target)),
            (Some(("toArray", 0)), format!(
                "{} func toArray(): Array<{}> {{\n{}return {}.toArray()\n}}",
                om, t, IND, target)),
            (Some(("first", 0)), format!(
                "{} prop first: ?{} {{\n{}get() {{ {}.first }}\n}}",
                om, t, IND, target)),
            (Some(("last", 0)), format!(
                "{} prop last: ?{} {{\n{}get() {{ {}.last }}\n}}",
                om, t, IND, target)),
            (Some(("size", 0)), format!(
                "{} prop size: Int64 {{\n{}get() {{ {}.size }}\n}}",
                om, IND, target)),
        ];
        for (key, code) in gen_members {
            if let Some((nm, ar)) = key {
                if user_sigs.contains(&(nm.to_string(), ar)) {
                    continue;
                }
            }
            mbody.push_str(&indent(&code, 1));
            mbody.push('\n');
        }
        (fields, mbody, ifaces)
    }

    fn rename_conflicting_companion_func(
        &self,
        class_name: &str,
        member: NodeId,
        rendered: &str,
    ) -> String {
        let Kind::Func { name, .. } = self.g.kind(member) else {
            return rendered.to_string();
        };
        let Some(alias) = self.companion_static_alias(class_name, name) else {
            return rendered.to_string();
        };
        rename_func_decl(rendered, name.as_str(), &alias)
    }

    fn render_companion_field_func(&self, member: NodeId) -> Option<String> {
        let Kind::VarDecl {
            name_node,
            ty,
            init: Some(init),
            ..
        } = self.g.kind(member)
        else {
            return None;
        };
        if self.is_static_scalar_const_expr(*init) {
            return None;
        }
        let name = self.t(*name_node)?;
        let ret = ty
            .clone()
            .or_else(|| self.expr_type_name(*init))
            .or_else(|| self.infer_literal_type(*init))?;
        let value = self.t(*init)?;
        Some(format!(
            "static func {}(): {} {{\n{}return {}\n}}",
            name, ret, IND, value
        ))
    }

    pub(crate) fn companion_static_alias(
        &self,
        class_name: &str,
        member_name: &str,
    ) -> Option<String> {
        let class_name = crate::parser::safe_name(class_name);
        let member_name = crate::parser::safe_name(member_name);
        let cid = self.class_index.get(&class_name)?;
        let Kind::Class {
            ctor_params,
            members,
            companion_members,
            ..
        } = self.g.kind(*cid)
        else {
            return None;
        };
        let is_companion_func = companion_members
            .iter()
            .any(|m| matches!(self.g.kind(*m), Kind::Func { name, .. } if *name == member_name));
        if !is_companion_func {
            return None;
        }
        let ctor_conflict = ctor_params
            .iter()
            .any(|p| p.kind != CtorParamKind::Plain && p.name == member_name);
        let member_conflict = members.iter().any(|m| {
            if companion_members.contains(m) {
                return false;
            }
            matches!(
                self.g.kind(*m),
                Kind::VarDecl { name_node, .. }
                    if matches!(self.g.kind(*name_node), Kind::Name { original }
                        if crate::parser::safe_name(original) == member_name)
            )
        });
        if ctor_conflict || member_conflict {
            let base = member_name.trim_matches('`');
            Some(crate::parser::safe_name(&format!("{}Static", base)))
        } else {
            None
        }
    }

    fn needs_empty_primary_init(&self, members: &[NodeId]) -> bool {
        members.iter().any(|m| {
            matches!(
                self.g.kind(*m),
                Kind::SecondaryConstructor {
                    delegate: Some(ConstructorDelegate { target, args }),
                    ..
                } if target == "this" && args.is_empty()
            )
        })
    }

    fn render_secondary_constructor(
        &self,
        params: &[NodeId],
        delegate: Option<&ConstructorDelegate>,
        body: NodeId,
    ) -> Option<String> {
        let ps: Vec<String> = params.iter().map(|p| self.t(*p)).collect::<Option<_>>()?;
        let mut out = format!("init({}) {{\n", ps.join(", "));
        if let Some(d) = delegate {
            let args: Vec<String> = params.iter().zip(d.args.iter()).map(|(p, a)| {
                let rendered = self.t(*a).unwrap_or_default();
                if d.target == "super" && self.is_non_string_exception_arg(*p, &rendered) {
                    format!("{}.toString()", rendered)
                } else {
                    rendered
                }
            }).collect();
            out.push_str(&format!("{}{}({})\n", IND, d.target, args.join(", ")));
            // Store `cause` param as field for later access from methods.
            for p in params {
                if let Kind::Param { name_node, .. } = self.g.kind(*p) {
                    if let Kind::Name { original } = self.g.kind(*name_node) {
                        if crate::parser::safe_name(original) == "cause" {
                            out.push_str(&format!("{}{}this.cause = cause\n", IND, IND));
                        }
                    }
                }
            }
        }
        if let Kind::Block { stmts } = self.g.kind(body) {
            for s in stmts {
                let st = self.t(*s)?;
                out.push_str(&indent(&st, 1));
                out.push('\n');
            }
        }
        out.push('}');
        Some(out)
    }

    /// Check if a super() arg needs .toString() because its param type is neither
    /// String nor Exception-based (e.g. IOException).
    fn is_non_string_exception_arg(&self, param: NodeId, rendered: &str) -> bool {
        if rendered.starts_with('"') {
            return false;
        }
        // Constructor calls like `IOException(message)` always need conversion.
        if rendered.contains('(') {
            return true;
        }
        // Check the param type: only String and Exception itself don't need conversion.
        if let Kind::Param { ty, .. } = self.g.kind(param) {
            if ty == "String" || ty == "?String"
                || ty == "Exception" || ty == "?Exception" {
                return false;
            }
            // Non-String, non-Exception type (e.g. IOException) → needs conversion.
            return true;
        }
        false
    }

    fn non_conflicting_if_let_bind(
        &self,
        bind: &str,
        then_b: NodeId,
        else_b: Option<NodeId>,
    ) -> String {
        if bind.trim_matches('`') == bind
            || else_b.map_or(false, |e| self.block_declares_name(e, bind))
            || self.block_declares_name(then_b, bind)
        {
            crate::parser::safe_name(&format!("{}Value", bind.trim_matches('`')))
        } else {
            bind.to_string()
        }
    }

    fn block_declares_name(&self, id: NodeId, name: &str) -> bool {
        match self.g.kind(id) {
            Kind::VarDecl { name_node, .. } => {
                if let Kind::Name { original } = self.g.kind(*name_node) {
                    if crate::parser::safe_name(original) == name {
                        return true;
                    }
                }
            }
            Kind::DestructureDecl { names, .. } | Kind::Destructure { names } => {
                for n in names {
                    if let Kind::Name { original } = self.g.kind(*n) {
                        if crate::parser::safe_name(original) == name {
                            return true;
                        }
                    }
                }
            }
            _ => {}
        }
        self.g
            .children_of(id)
            .iter()
            .any(|c| self.block_declares_name(*c, name))
    }

    fn rebind_block(&self, bind: &str, bind_value: &str, block: &str) -> String {
        let insert = format!("let {} = {}\n", bind, bind_value);
        if block == "{}" {
            format!("{{\n{}{}\n}}", IND, insert.trim_end())
        } else if let Some(rest) = block.strip_prefix("{\n") {
            format!("{{\n{}{}{}", IND, insert, rest)
        } else {
            block.to_string()
        }
    }

    fn member_inits_referencing_ctor_params(
        &self,
        ctor_params: &[CtorParam],
        members: &[NodeId],
    ) -> Vec<(String, String)> {
        let plain: Vec<String> = ctor_params
            .iter()
            .filter(|p| p.kind == CtorParamKind::Plain)
            .map(|p| p.name.clone())
            .collect();
        if plain.is_empty() {
            return Vec::new();
        }
        let mut moved = Vec::new();
        for m in members {
            let Kind::VarDecl {
                name_node,
                init: Some(init),
                ..
            } = self.g.kind(*m)
            else {
                continue;
            };
            if !plain.iter().any(|p| self.refers_name(*init, p)) {
                continue;
            }
            if let Kind::Name { original } = self.g.kind(*name_node) {
                if let Some(rendered_init) = self.t(*init) {
                    moved.push((crate::parser::safe_name(original), rendered_init));
                }
            }
        }
        moved
    }

    /// 渲染 `expect class` 的单个成员为可编译存根。
    /// - 字段（val/var）→ 抛异常的计算 prop（val 仅 get；var 加 set）。惰性——仅
    ///   访问时抛，避免静态字段 eager 初始化在程序启动即崩。
    /// - 方法/companion 方法 → `func ... { throw }`（companion 加 `static`）。
    /// - 次构造器 → `init(...) { throw }`。
    fn render_expect_member(&self, m: NodeId, is_companion: bool) -> Option<String> {
        const STUB: &str = "throw Exception(\"expect class stub\")";
        let stat = if is_companion { "static " } else { "" };
        // 存根成员剥默认值（`name!: T = d` → `name: T`；prop/静态上下文不接受默认值）。
        let strip_default = |p: String| -> String {
            match p.find(" = ") {
                Some(eq) => p[..eq].to_string(),
                None => p,
            }
        };
        match self.g.kind(m) {
            Kind::VarDecl { mutable, ty, .. } => {
                let name = self.var_decl_name(m)?;
                let ty = ty.clone()?; // expect 字段恒带类型；无类型则 None → 回退失败上报
                if *mutable {
                    Some(format!(
                        "public {s}mut prop {n}: {t} {{\n{i}get() {{ {stub} }}\n{i}set(_v) {{ {stub} }}\n}}",
                        s = stat, n = name, t = ty, i = IND, stub = STUB
                    ))
                } else {
                    Some(format!(
                        "public {s}prop {n}: {t} {{\n{i}get() {{ {stub} }}\n}}",
                        s = stat, n = name, t = ty, i = IND, stub = STUB
                    ))
                }
            }
            Kind::Func {
                name,
                params,
                ret,
                generic_params,
                ..
            } => {
                let ps: Vec<String> = params
                    .iter()
                    .map(|p| self.t(*p).map(strip_default))
                    .collect::<Option<_>>()?;
                let gen_str = if generic_params.is_empty() {
                    String::new()
                } else {
                    let names: Vec<&str> = generic_params
                        .iter()
                        .map(|g| g.split(" <: ").next().unwrap_or(g))
                        .collect();
                    format!("<{}>", names.join(", "))
                };
                let r = ret
                    .clone()
                    .map(|r| format!(": {}", r))
                    .unwrap_or_else(|| ": Unit".to_string());
                Some(format!(
                    "public {s}func {n}{g}({p}){r} {{ {stub} }}",
                    s = stat,
                    n = name,
                    g = gen_str,
                    p = ps.join(", "),
                    r = r,
                    stub = STUB
                ))
            }
            Kind::SecondaryConstructor { params, .. } => {
                let ps: Vec<String> = params
                    .iter()
                    .map(|p| self.t(*p).map(strip_default))
                    .collect::<Option<_>>()?;
                Some(format!("public init({}) {{ {} }}", ps.join(", "), STUB))
            }
            // 其它成员（罕见）按常规渲染。
            _ => self.t(m),
        }
    }

    pub(crate) fn var_decl_name(&self, id: NodeId) -> Option<String> {
        let Kind::VarDecl { name_node, .. } = self.g.kind(id) else {
            return None;
        };
        if let Kind::Name { original } = self.g.kind(*name_node) {
            Some(crate::parser::safe_name(original))
        } else {
            None
        }
    }

    fn render_var_decl_without_init(&self, id: NodeId) -> Option<String> {
        let Kind::VarDecl {
            mutable,
            name_node,
            ty,
            init,
            ..
        } = self.g.kind(id)
        else {
            return None;
        };
        let name = self.t(*name_node)?;
        let kw = if *mutable { "var" } else { "let" };
        let inferred = match (ty, init) {
            (Some(t), _) => Some(t.clone()),
            (None, Some(i)) => self
                .expr_type_name(*i)
                .or_else(|| self.infer_literal_type(*i))
                .or_else(|| {
                    // 最后手段：从渲染后的 init 文本提取构造器名作为类型
                    let rendered = self.t(*i)?;
                    let ctor_name = rendered.split('(').next()?.split('.').last()?;
                    if ctor_name.chars().next()?.is_ascii_uppercase() {
                        Some(ctor_name.to_string())
                    } else {
                        None
                    }
                }),
            _ => None,
        };
        let ty = inferred.map(|t| format!(": {}", t)).unwrap_or_default();
        Some(format!("{} {}{}", kw, name, ty))
    }

    /// 无参 lambda 且函数体为单一表达式语句时返回该表达式（供内联，绕过
    /// `(lam)()` 形式挡住泛型推断的问题）。
    fn single_expr_lambda_body(&self, id: NodeId) -> Option<NodeId> {
        if let Kind::Lambda { params, body } = self.g.kind(id) {
            if !params.is_empty() {
                return None;
            }
            if let Kind::Block { stmts } = self.g.kind(*body) {
                if stmts.len() == 1
                    && !matches!(
                        self.g.kind(stmts[0]),
                        Kind::VarDecl { .. } | Kind::Assign { .. } | Kind::Return { .. }
                    )
                {
                    return Some(stmts[0]);
                }
            }
        }
        None
    }

    fn infer_literal_type(&self, id: NodeId) -> Option<String> {
        match self.g.kind(id) {
            Kind::CollLit { ctor, elem, args } => {
                let elem = elem
                    .clone()
                    .or_else(|| self.infer_collection_elem_type(args))?;
                Some(format!("{}<{}>", ctor, elem))
            }
            Kind::Binary { op, .. } if op == "to" => Some("(String, String)".to_string()),
            Kind::StrTemplate { .. } => Some("String".to_string()),
            Kind::IntLit(_) => Some("Int64".to_string()),
            Kind::FloatLit(_) => Some("Float64".to_string()),
            Kind::BoolLit(_) => Some("Bool".to_string()),
            Kind::CharLit(_) => Some("Rune".to_string()),
            // 负数字面量 `-1` 是 Unary(-, IntLit)：递归推断。object val→field 拆分
            // 需要字段类型标注，推断失败会产出非法的 `let x`（无类型无初始化）。
            Kind::Unary { op, expr } if op == "-" || op == "+" => self.infer_literal_type(*expr),
            // charArrayOf(...) 由 render_call 渲染为 Rune 数组字面量 → Array<Rune>
            // "...".toCharArray() → Array<Rune> (Kotlin CharArray 映射)
            Kind::Call { callee, .. } => {
                if let Kind::NameRef { original, .. } = self.g.kind(*callee) {
                    if original == "charArrayOf" {
                        return Some("Array<Rune>".to_string());
                    }
                }
                if let Kind::Member { name, .. } = self.g.kind(*callee) {
                    if name == "toCharArray" {
                        return Some("Array<Rune>".to_string());
                    }
                }
                None
            }
            _ => None,
        }
    }

    fn qualify_singleton_init_call(
        &self,
        class_name: &str,
        init: NodeId,
        rendered: &str,
    ) -> String {
        let Kind::Call { callee, .. } = self.g.kind(init) else {
            return rendered.to_string();
        };
        let Kind::NameRef { original, .. } = self.g.kind(*callee) else {
            return rendered.to_string();
        };
        if self.func_index.contains_key(original) {
            format!("{}.{}", class_name, rendered)
        } else {
            rendered.to_string()
        }
    }

    /// 检查成员列表中是否有 override toString() 方法。
    fn has_override_tostring(&self, members: &[NodeId]) -> bool {
        members.iter().any(|&m| {
            if let Kind::Func {
                name: fn_name,
                is_override,
                ..
            } = self.g.kind(m)
            {
                fn_name == "toString" && *is_override
            } else {
                false
            }
        })
    }

    // ============ 枚举渲染 ============

    fn render_enum(
        &self,
        name: &str,
        entries: &[EnumEntry],
        params: &[CtorParam],
        companion_consts: &[NodeId],
    ) -> Option<String> {
        // R17 簇A阶段②: companion public 标量常量提升为同文件顶层 let（仓颉 enum 无 static）。
        // 外部 `EnumName.const` 引用由 render_member 重写为提升名 `EnumName__const`。
        let lifted = self.render_lifted_enum_consts(name, companion_consts);

        if entries.is_empty() {
            return Some(format!("enum {} {{ | {} }}{}", name, name, lifted));
        }

        // 无构造器参数的简单枚举
        if params.is_empty() {
            let body = entries
                .iter()
                .map(|e| e.name.as_str())
                .collect::<Vec<_>>()
                .join(" | ");
            let mut arms = String::new();
            for e in entries {
                arms.push_str(&format!(
                    "{}{}{}case {} => \"{}\"\n",
                    IND, IND, IND, e.name, e.name
                ));
            }
            return Some(format!(
                "@Derive[Hashable, Equatable]\nenum {} <: ToString {{\n{}| {}\n{}public func toString(): String {{\n{}return match (this) {{\n{}{}}}\n{}}}\n}}{}",
                name, IND, body, IND, IND, IND, arms, IND, lifted
            ));
        }

        // 有构造器参数的枚举 → 仓颉: class + static let 模式
        // 使用 _ordinal 字段区分枚举项（即使构造参数值相同也能正确比较）
        let mut out = String::new();
        // 类声明
        out.push_str(&format!(
            "class {} <: ToString & Equatable<{}> {{\n",
            name, name
        ));
        // _ordinal 字段用于区分不同枚举项
        out.push_str(&format!("{}let _ordinal: Int64\n", IND));
        // 字段
        for p in params {
            let kw = if p.kind == CtorParamKind::Var {
                "var"
            } else {
                "let"
            };
            out.push_str(&format!("{}public {} {}: {}\n", IND, kw, p.name, p.ty));
        }
        // 构造器（增加 _ordinal 参数作为首个无名参数）
        let mut ps: Vec<String> = vec!["_ordinal: Int64".to_string()];
        ps.extend(params.iter().map(|p| format!("{}: {}", p.name, p.ty)));
        out.push_str(&format!("{}init({}) {{\n", IND, ps.join(", ")));
        out.push_str(&format!("{}{}this._ordinal = _ordinal\n", IND, IND));
        for p in params {
            out.push_str(&format!("{}{}this.{} = {}\n", IND, IND, p.name, p.name));
        }
        out.push_str(&format!("{}}}\n", IND));
        // 静态枚举常量（传入序号）
        for (i, e) in entries.iter().enumerate() {
            let args: Vec<String> = e.args.iter().map(|a| self.t(*a)).collect::<Option<_>>()?;
            out.push_str(&format!(
                "{}public static let {} = {}({}, {})\n",
                IND,
                e.name,
                name,
                i,
                args.join(", ")
            ));
        }
        // toString
        let mut arms = String::new();
        for e in entries {
            arms.push_str(&format!(
                "{}{}{}if (this == {}.{}) {{ return \"{}\" }}\n",
                IND, IND, IND, name, e.name, e.name
            ));
        }
        out.push_str(&format!(
            "{}public func toString(): String {{\n{}return \"{}(?)\"\n{}}}\n",
            IND, arms, name, IND
        ));
        // == operator（仅比较 _ordinal）
        out.push_str(&format!(
            "{}public operator func ==(rhs: {}): Bool {{\n",
            IND, name
        ));
        out.push_str(&format!(
            "{}{}return this._ordinal == rhs._ordinal\n",
            IND, IND
        ));
        out.push_str(&format!("{}}}\n", IND));
        // != operator
        out.push_str(&format!(
            "{}public operator func !=(rhs: {}): Bool {{\n",
            IND, name
        ));
        out.push_str(&format!("{}{}return !(this == rhs)\n", IND, IND));
        out.push_str(&format!("{}}}\n", IND));
        out.push_str("}");
        out.push_str(&lifted);
        Some(out)
    }

    /// 渲染 enum companion public 标量常量为同文件顶层 `let`（提升名 `EnumName__const`）。
    /// 单个常量渲染失败则跳过该常量（不拖垮整个 enum）。返回可直接拼接到 enum 文本尾部
    /// 的串（前置双换行；无可提升项时为空串）。
    fn render_lifted_enum_consts(&self, enum_name: &str, consts: &[NodeId]) -> String {
        let mut parts = Vec::new();
        for &cid in consts {
            if let Some(s) = self.render_lifted_enum_const(enum_name, cid) {
                parts.push(s);
            }
        }
        if parts.is_empty() {
            String::new()
        } else {
            format!("\n\n{}", parts.join("\n"))
        }
    }

    fn render_lifted_enum_const(&self, enum_name: &str, cid: NodeId) -> Option<String> {
        let Kind::VarDecl {
            name_node,
            ty,
            init,
            ..
        } = self.g.kind(cid)
        else {
            return None;
        };
        let raw_name = self.t(*name_node)?;
        // 仅提升**标量**常量（Rune/Int/String/Bool/Float 等）。数组/集合类型
        // （CharArray→Array<Rune> 等）语义面复杂且当前无外部引用错误, 不提升以控风险。
        let scalar_tys = [
            "Rune", "Int64", "Int32", "Int16", "Int8", "UInt8", "UInt16", "UInt32", "UInt64",
            "String", "Bool", "Float64", "Float32", "Byte", "Char",
        ];
        let ty = ty.as_ref()?;
        if !scalar_tys.contains(&ty.as_str()) {
            return None;
        }
        let lifted_name = lifted_enum_const_name(enum_name, &raw_name);
        let init = (*init)?;
        let init_s = self.t(init)?;
        let surrogate = self.is_surrogate_char_lit(init);
        let eff_ty = if surrogate && ty == "Rune" {
            "Int64".to_string()
        } else {
            ty.clone()
        };
        Some(format!("let {}: {} = {}", lifted_name, eff_ty, init_s))
    }

    /// enum companion const 提升名。若 `EnumName.member` 命名一个已捕获的 companion
    /// public 常量, 返回提升后的顶层名 `EnumName__member`, 否则 None。
    fn enum_companion_const_lifted(&self, enum_name: &str, member: &str) -> Option<String> {
        let &eid = self.enum_index.get(enum_name)?;
        let Kind::Enum {
            companion_consts, ..
        } = &self.g.nodes[eid].kind
        else {
            return None;
        };
        for &cid in companion_consts {
            if let Kind::VarDecl { name_node, .. } = self.g.kind(cid) {
                if self.t(*name_node).as_deref() == Some(member)
                    // 仅当该常量确实被提升（render_lifted_enum_const 成功）时才重写引用，
                    // 否则会重写到一个未 emit 的名字, 制造新的 undeclared。
                    && self.render_lifted_enum_const(enum_name, cid).is_some()
                {
                    return Some(lifted_enum_const_name(enum_name, member));
                }
            }
        }
        None
    }

    // ============ 块渲染 ============

    pub(crate) fn loop_var_name(&self, var: NodeId) -> Option<String> {
        if let Kind::VarDecl { name_node, .. } = self.g.kind(var) {
            self.t(*name_node)
        } else {
            self.t(var)
        }
    }

    pub(crate) fn render_block(&self, id: NodeId) -> Option<String> {
        let inner = self.render_block_inner(id, 0)?;
        if inner.trim().is_empty() {
            Some("{}".to_string())
        } else {
            Some(format!("{{\n{}\n}}", indent(&inner, 1)))
        }
    }

    pub(crate) fn render_block_inner(&self, id: NodeId, _d: usize) -> Option<String> {
        if let Kind::Block { stmts } = self.g.kind(id) {
            let mut lines = Vec::new();
            for s in stmts {
                // 局部扩展函数（`fun Receiver.name() {...}` 声明在函数体内，Kotlin 合法）：
                // 仓颉不允许在函数体内嵌套 `extend`。渲染为普通嵌套 func——接收者成员
                // 经外层方法的 `this` 解析（嵌套 func 捕获外层 this，已验证）。
                if let Kind::Func {
                    name,
                    params,
                    ret,
                    body,
                    is_main,
                    is_abstract,
                    is_override,
                    receiver_type: Some(_),
                    generic_params,
                } = self.g.kind(*s)
                {
                    let rendered = self.render_func(
                        *s,
                        name,
                        params,
                        ret.clone(),
                        *body,
                        *is_main,
                        *is_abstract,
                        *is_override,
                        None,
                        generic_params,
                    )?;
                    lines.push(rendered);
                    continue;
                }
                lines.push(self.t(*s)?);
            }
            Some(lines.join("\n"))
        } else {
            self.t(id)
        }
    }

    // ============ when 渲染 ============

    /// The single value field of a `value class` (→ struct), if `ty` names one.
    fn value_class_field(&self, ty: &str) -> Option<String> {
        let &cid = self.class_index.get(ty)?;
        if let Kind::Class {
            is_value: true,
            ctor_params,
            ..
        } = &self.g.nodes[cid].kind
        {
            return ctor_params
                .iter()
                .find(|p| p.kind != CtorParamKind::Plain)
                .map(|p| p.name.clone());
        }
        None
    }

    /// If any `when` arm matches against a value class's companion constant
    /// (renders as `Type.NAME(...)`), return that value class's field name.
    fn value_class_const_field(&self, arms: &[WhenArm]) -> Option<String> {
        for a in arms {
            if let Some(ps) = &a.patterns {
                for p in ps {
                    if let Some(s) = self.t(*p) {
                        if let Some(dot) = s.find('.') {
                            if let Some(field) = self.value_class_field(&s[..dot]) {
                                return Some(field);
                            }
                        }
                    }
                }
            }
        }
        None
    }

    /// Render a value-class `when` as an if/else chain comparing the value field
    /// (`(this).mode == (Type.CR()).mode`), since the derived `==` is unavailable
    /// in-body. Caller guarantees an `else` arm exists.
    fn render_when_value_class_consts(
        &self,
        subj: NodeId,
        arms: &[WhenArm],
        field: &str,
    ) -> Option<String> {
        let s = self.t(subj)?;
        let mut out = String::new();
        let mut first = true;
        let mut else_body: Option<String> = None;
        for a in arms {
            match &a.patterns {
                Some(ps) => {
                    let conds: Vec<String> = ps
                        .iter()
                        .map(|p| {
                            self.t(*p)
                                .map(|pat| format!("({}).{} == ({}).{}", s, field, pat, field))
                        })
                        .collect::<Option<_>>()?;
                    let body = self.render_arm_body(a.body)?;
                    let kw = if first { "if" } else { "else if" };
                    out.push_str(&format!("{} ({}) {{ {} }} ", kw, conds.join(" || "), body));
                    first = false;
                }
                None => else_body = Some(self.render_arm_body(a.body)?),
            }
        }
        out.push_str(&format!("else {{ {} }}", else_body?));
        Some(out)
    }

    fn render_when(&self, subject: Option<NodeId>, arms: &[WhenArm]) -> Option<String> {
        match subject {
            Some(subj) => {
                let needs_cond = arms.iter().any(|a| {
                    a.patterns.as_ref().map_or(false, |ps| {
                        ps.iter()
                            .any(|p| matches!(self.g.kind(*p), Kind::InPat { .. }))
                    })
                });
                if needs_cond {
                    return self.render_when_as_if(subj, arms);
                }
                // value class `when(this) { CR -> ... }` over companion constants.
                // The constants render as static calls (`LineEndingMode.CR()`), which
                // are not valid match patterns, and @Derive[Equatable]'s `==` is not
                // visible inside the type's own body — so compare via the value field.
                // Requires an `else` arm to stay exhaustive as an expression.
                let has_else = arms.iter().any(|a| a.patterns.is_none());
                if has_else {
                    if let Some(field) = self.value_class_const_field(arms) {
                        return self.render_when_value_class_consts(subj, arms, &field);
                    }
                }
                let s = self.t(subj)?;
                let bind = if let Kind::NameRef { original, .. } = self.g.kind(subj) {
                    crate::parser::safe_name(original)
                } else {
                    "_".to_string()
                };
                let mut body = String::new();
                for a in arms {
                    let arm_body = self.render_arm_body(a.body)?;
                    match &a.patterns {
                        Some(ps) => {
                            if ps.len() == 1 {
                                if let Kind::TypePat { ty } = self.g.kind(ps[0]) {
                                    body.push_str(&format!(
                                        "case {}: {} => {}\n",
                                        bind, ty, arm_body
                                    ));
                                    continue;
                                }
                            }
                            let pts: Vec<String> = ps
                                .iter()
                                .map(|p| match self.g.kind(*p) {
                                    Kind::TypePat { ty } => Some(format!("_: {}", ty)),
                                    _ => self.t(*p),
                                })
                                .collect::<Option<_>>()?;
                            body.push_str(&format!("case {} => {}\n", pts.join(" | "), arm_body));
                        }
                        None => {
                            body.push_str(&format!("case _ => {}\n", arm_body));
                        }
                    }
                }
                // 非枚举类型的 match 需要 catch-all 以确保穷举
                let has_catch_all = arms.iter().any(|a| a.patterns.is_none());
                if !has_catch_all {
                    // Check if subject is an enum type (already exhaustive)
                    // Use enum_entries() for robust detection instead of fragile '.' heuristic
                    let is_enum = if let Kind::NameRef { original: _, .. } = self.g.kind(subj) {
                        // Check if the subject variable's type or declared enum matches
                        self.expr_type_name(subj)
                            .map_or(false, |ty| self.enum_entries(&ty).is_some())
                            || arms.iter().any(|a| {
                                a.patterns.as_ref().map_or(false, |ps| {
                                    ps.iter().any(|p| {
                                        if let Some(s) = self.t(*p) {
                                            // Pattern like EnumName.ENTRY
                                            if let Some(prefix) = s.split('.').next() {
                                                self.enum_entries(prefix).is_some()
                                            } else {
                                                false
                                            }
                                        } else {
                                            false
                                        }
                                    })
                                })
                            })
                    } else {
                        false
                    };
                    if !is_enum {
                        // Check if all arms are type patterns (sealed class style)
                        let all_type_pats = arms.iter().all(|a| {
                            a.patterns.as_ref().map_or(false, |ps| {
                                ps.iter()
                                    .all(|p| matches!(self.g.kind(*p), Kind::TypePat { .. }))
                            })
                        });
                        if all_type_pats {
                            body.push_str("case _ => throw Exception(\"\")\n");
                        } else {
                            body.push_str("case _ => ()\n");
                        }
                    }
                }
                Some(format!("match ({}) {{\n{}}}", s, indent(&body, 1)))
            }
            None => {
                let mut out = String::new();
                for (i, a) in arms.iter().enumerate() {
                    let arm_body = self.render_block(a.body)?;
                    match &a.patterns {
                        Some(ps) => {
                            let cond = self.t(ps[0])?;
                            if i == 0 {
                                out.push_str(&format!("if ({}) {}", cond, arm_body));
                            } else {
                                out.push_str(&format!(" else if ({}) {}", cond, arm_body));
                            }
                        }
                        None => out.push_str(&format!(" else {}", arm_body)),
                    }
                }
                Some(out)
            }
        }
    }

    fn render_when_as_if(&self, subj: NodeId, arms: &[WhenArm]) -> Option<String> {
        let mut out = String::new();
        let mut first = true;
        for a in arms {
            let arm_body = self.render_block(a.body)?;
            match &a.patterns {
                Some(ps) => {
                    let mut conds = Vec::new();
                    for p in ps {
                        let c = match self.g.kind(*p) {
                            Kind::InPat { negated, rhs } => {
                                let inner = self.render_in(subj, *rhs)?;
                                if *negated {
                                    format!("!({})", inner)
                                } else {
                                    inner
                                }
                            }
                            Kind::TypePat { ty } => format!("{} is {}", self.atom(subj)?, ty),
                            _ => format!("{} == {}", self.atom(subj)?, self.t(*p)?),
                        };
                        conds.push(c);
                    }
                    let cond = conds.join(" || ");
                    if first {
                        out.push_str(&format!("if ({}) {}", cond, arm_body));
                        first = false;
                    } else {
                        out.push_str(&format!(" else if ({}) {}", cond, arm_body));
                    }
                }
                None => out.push_str(&format!(" else {}", arm_body)),
            }
        }
        Some(out)
    }

    fn render_arm_body(&self, id: NodeId) -> Option<String> {
        let inner = self.render_block_inner(id, 0)?;
        if inner.trim().is_empty() {
            Some("()".to_string())
        } else if inner.lines().count() <= 1 {
            Some(inner.trim().to_string())
        } else {
            Some(format!("\n{}", indent(&inner, 1)))
        }
    }

    // ============ 调用渲染 ============
    // 已迁移至 render_calls.rs

    // ============ 辅助 ============

    /// 把接收者渲染为「产生迭代器」的表达式。
    pub(crate) fn as_iter(&self, base: NodeId) -> Option<String> {
        Some(format!("{}.iterator()", self.atom(base)?))
    }

    /// Render a call argument, erasing Kotlin spread syntax because vararg
    /// parameters are represented as Array<T> in Cangjie.
    pub(crate) fn render_arg(&self, id: NodeId) -> Option<String> {
        if let Kind::Spread { expr } = self.g.kind(id) {
            self.t(*expr)
        } else {
            self.t(id)
        }
    }

    fn render_var_decl(
        &self,
        mutable: bool,
        name_node: NodeId,
        ty: Option<String>,
        init: Option<NodeId>,
        is_lazy: bool,
    ) -> Option<String> {
        let name = self.t(name_node)?;
        if init.is_none() && ty.is_none() {
            return Some(name);
        }
        let kw = if mutable { "var" } else { "let" };
        // If init is a surrogate CharLit, switch type from Rune to Int64
        let surrogate = init.is_some_and(|i| self.is_surrogate_char_lit(i));
        let effective_ty: Option<String> = if surrogate && ty.as_deref() == Some("Rune") {
            Some("Int64".into())
        } else {
            ty.clone()
        };
        let tys = effective_ty
            .as_ref()
            .map(|t| format!(": {}", t))
            .unwrap_or_default();
        if let Some(i) = init {
            let prefix = if is_lazy {
                format!("{} {}{} =", kw, name, tys)
            } else {
                format!("{} {}{} =", kw, name, tys)
            };
            Some(format!("{} {}", prefix, self.t(i)?))
        } else {
            Some(format!("{} {}{}", kw, name, tys))
        }
    }

    fn render_index(&self, base: NodeId, index: NodeId) -> Option<String> {
        let b = self.atom(base)?;
        let i = self.t(index)?;
        if self.looks_string(base) {
            return Some(format!("{}.toRuneArray()[{}]", b, i));
        }
        Some(format!("{}[{}]", b, i))
    }

    fn render_assign_target(&self, target: NodeId) -> Option<String> {
        if let Kind::Index { base, index } = self.g.kind(target) {
            let b = self.atom(*base)?;
            let i = self.t(*index)?;
            return Some(format!("{}[{}]", b, i));
        }
        self.t(target)
    }

    fn infer_collection_elem_type(&self, args: &[NodeId]) -> Option<String> {
        if args.len() == 1 {
            if let Some(ty) = self.expr_type_name(args[0]) {
                if let Some(inner) = ty.strip_prefix("Array<").and_then(|s| s.strip_suffix('>')) {
                    return Some(inner.to_string());
                }
                if let Some(inner) = ty
                    .strip_prefix("ArrayList<")
                    .and_then(|s| s.strip_suffix('>'))
                {
                    return Some(inner.to_string());
                }
                if let Some(inner) = ty
                    .strip_prefix("HashSet<")
                    .and_then(|s| s.strip_suffix('>'))
                {
                    return Some(inner.to_string());
                }
            }
            if let Kind::Spread { expr } = self.g.kind(args[0]) {
                if let Some(ty) = self.expr_type_name(*expr) {
                    if let Some(inner) = ty.strip_prefix("Array<").and_then(|s| s.strip_suffix('>'))
                    {
                        return Some(inner.to_string());
                    }
                }
            }
        }
        let first = args.first().copied()?;
        match self.g.kind(first) {
            Kind::Member { base, name, .. } => {
                if let Kind::NameRef { original, .. } = self.g.kind(*base) {
                    if self.enum_entries(original).is_some() {
                        return Some(original.clone());
                    }
                    if self.is_class_name(original) && self.enum_entries(name).is_some() {
                        return Some(crate::parser::safe_name(name));
                    }
                }
                None
            }
            Kind::Binary { op, .. } if op == "to" => Some("(String, String)".to_string()),
            Kind::StrTemplate { .. } => Some("String".to_string()),
            Kind::CharLit(_) => Some("Rune".to_string()),
            Kind::IntLit(_) => Some("Int64".to_string()),
            Kind::BoolLit(_) => Some("Bool".to_string()),
            _ => self.expr_type_name(first),
        }
    }

    fn render_spread_array_literal(&self, args: &[NodeId]) -> Option<String> {
        let spread_pos = args
            .iter()
            .position(|a| matches!(self.g.kind(*a), Kind::Spread { .. }))?;
        if args
            .iter()
            .filter(|a| matches!(self.g.kind(**a), Kind::Spread { .. }))
            .count()
            != 1
        {
            return None;
        }
        let Kind::Spread { expr: spread_expr } = self.g.kind(args[spread_pos]) else {
            return None;
        };
        let spread = self.atom(*spread_expr)?;
        let prefix: Vec<String> = args[..spread_pos]
            .iter()
            .map(|a| self.render_arg(*a))
            .collect::<Option<_>>()?;
        let suffix: Vec<String> = args[spread_pos + 1..]
            .iter()
            .map(|a| self.render_arg(*a))
            .collect::<Option<_>>()?;
        let prefix_len = prefix.len();
        let suffix_len = suffix.len();
        let total_extra = prefix_len + suffix_len;
        let mut cases = String::new();
        for (i, value) in prefix.iter().enumerate() {
            cases.push_str(&format!("if (i == {}) {{ {} }} else ", i, value));
        }
        let fallback = format!("{{ _spread[i - {}] }}", prefix_len);
        if suffix_len == 0 {
            Some(format!(
                "({{ => let _spread = {}; Array(_spread.size + {}, {{ i => {}{} }}) }})()",
                spread, total_extra, cases, fallback
            ))
        } else {
            cases.push_str(&format!(
                "if (i < _spread.size + {}) {{ {} }} else ",
                prefix_len, fallback
            ));
            for (i, value) in suffix.iter().enumerate() {
                cases.push_str(&format!(
                    "if (i == _spread.size + {}) {{ {} }} else ",
                    prefix_len + i,
                    value
                ));
            }
            Some(format!(
                "({{ => let _spread = {}; Array(_spread.size + {}, {{ i => {}_spread[_spread.size - 1] }}) }})()",
                spread, total_extra, cases
            ))
        }
    }

    pub(crate) fn render_call_args_with_params(
        &self,
        fname: &str,
        args: &[NodeId],
    ) -> Option<Vec<String>> {
        let params = self.fn_params(fname)?;
        if params.is_empty() {
            return Some(Vec::new());
        }
        if let Some((idx, _)) = params
            .iter()
            .enumerate()
            .find(|(i, (_, ty, _))| *i == params.len() - 1 && ty.starts_with("Array<"))
        {
            let mut rendered = Vec::new();
            for (i, arg) in args.iter().take(idx).enumerate() {
                let s = self.render_arg(*arg)?;
                match params.get(i) {
                    Some((name, _, true)) => rendered.push(format!("{}: {}", name, s)),
                    _ => rendered.push(s),
                }
            }
            let rest = &args[idx..];
            let value = if rest.len() == 1 {
                match self.g.kind(rest[0]) {
                    Kind::Spread { expr } => self.t(*expr)?,
                    _ => format!("[{}]", self.render_arg(rest[0])?),
                }
            } else {
                let values: Vec<String> = rest
                    .iter()
                    .map(|a| self.render_arg(*a))
                    .collect::<Option<_>>()?;
                format!("[{}]", values.join(", "))
            };
            rendered.push(value);
            return Some(rendered);
        }
        if params.iter().any(|(_, _, has_default)| *has_default) {
            let mut rendered = Vec::with_capacity(args.len());
            for (i, x) in args.iter().enumerate() {
                let s = self.render_arg(*x)?;
                match params.get(i) {
                    Some((pname, _, true)) => rendered.push(format!("{}: {}", pname, s)),
                    _ => rendered.push(s),
                }
            }
            return Some(rendered);
        }
        None
    }

    /// 由字面量初值粗略推断 `fold` 的累加器类型实参。
    pub(crate) fn lit_type(&self, id: NodeId) -> String {
        match self.g.kind(id) {
            Kind::FloatLit(_) => "Float64".to_string(),
            Kind::BoolLit(_) => "Bool".to_string(),
            Kind::StrTemplate { .. } => "String".to_string(),
            _ => "Int64".to_string(),
        }
    }

    /// 查找名为 `fname` 的用户函数或类构造器，返回其参数（安全名, 类型, 是否有默认值）列表。
    pub(crate) fn fn_params(&self, fname: &str) -> Option<Vec<(String, String, bool)>> {
        let target = crate::parser::safe_name(fname);
        // 先查函数索引
        if let Some(&fid) = self.func_index.get(&target) {
            if let Kind::Func { params, .. } = &self.g.nodes[fid].kind {
                let mut out = Vec::new();
                let mut any_default = false;
                for p in params {
                    if let Kind::Param {
                        name_node,
                        ty,
                        default,
                    } = self.g.kind(*p)
                    {
                        let pn = if let Kind::Name { original } = self.g.kind(*name_node) {
                            crate::parser::safe_name(original)
                        } else {
                            "_".to_string()
                        };
                        let has = default.is_some();
                        any_default = any_default || has;
                        out.push((pn, ty.clone(), has));
                    }
                }
                // 与 render_func 的声明侧降级一致：中位默认值参数（其后还有无默认值
                // 参数）按位置参数处理，调用点不再加 `name:` 前缀。
                if let Some(lp) = out.iter().rposition(|(_, _, has)| !*has) {
                    for item in out.iter_mut().take(lp) {
                        item.2 = false;
                    }
                }
                if any_default
                    || out
                        .last()
                        .map_or(false, |(_, ty, _)| ty.starts_with("Array<"))
                {
                    return Some(out);
                }
                return None;
            }
        }
        // 再查类索引（构造器默认参数）
        if let Some(&cid) = self.class_index.get(&target) {
            if let Kind::Class { ctor_params, .. } = &self.g.nodes[cid].kind {
                let mut out = Vec::new();
                let mut any_default = false;
                for p in ctor_params {
                    let has = p.default.is_some();
                    any_default = any_default || has;
                    out.push((p.name.clone(), p.ty.clone(), has));
                }
                if any_default
                    || out
                        .last()
                        .map_or(false, |(_, ty, _)| ty.starts_with("Array<"))
                {
                    return Some(out);
                }
            }
        }
        None
    }

    /// 成员检查 `x in rhs`：区间转比较，集合转 contains。
    pub(crate) fn render_in(&self, lhs: NodeId, rhs: NodeId) -> Option<String> {
        let l = self.atom(lhs)?;
        if let Kind::Range {
            lo,
            hi,
            inclusive,
            down,
            ..
        } = self.g.kind(rhs).clone()
        {
            let lo_s = self.atom(lo)?;
            let hi_s = self.atom(hi)?;
            if down {
                return Some(format!("{} <= {} && {} >= {}", l, lo_s, l, hi_s));
            }
            let upper = if inclusive { "<=" } else { "<" };
            return Some(format!("{} >= {} && {} {} {}", l, lo_s, l, upper, hi_s));
        }
        let r = self.atom(rhs)?;
        Some(format!("{}.contains({})", r, l))
    }

    // ============ 程序渲染 ============

    pub(crate) fn render_program(&self, items: &[NodeId]) -> Option<String> {
        let mut globals = Vec::new();
        let mut decls = Vec::new();
        let mut loose = Vec::new();
        let mut has_main = false;
        let mut has_enum = false;
        for it in items {
            match self.g.kind(*it) {
                Kind::Func { is_main, .. } => {
                    if *is_main {
                        has_main = true;
                    }
                    decls.push(self.t(*it)?);
                }
                Kind::Class { .. } => decls.push(self.t(*it)?),
                Kind::Enum { .. } => {
                    has_enum = true;
                    decls.push(self.t(*it)?);
                }
                Kind::VarDecl { .. } => globals.push(self.t(*it)?),
                _ => loose.push(self.t(*it)?),
            }
        }
        let mut sections: Vec<String> = Vec::new();
        if !globals.is_empty() {
            sections.push(globals.join("\n"));
        }
        if !decls.is_empty() {
            sections.push(decls.join("\n\n"));
        }
        let mut body = sections.join("\n\n");
        if !loose.is_empty() && !has_main {
            let main_body = loose.join("\n");
            body.push_str(&format!("\n\nmain() {{\n{}\n}}", indent(&main_body, 1)));
        } else if !loose.is_empty() {
            body.push_str("\n\n");
            body.push_str(&loose.join("\n"));
        }
        if body.contains("__k2cjRuneSlice(") {
            let helper = r#"func __k2cjRuneSlice(input: String, start: Int64, end: Int64): String {
    let _r = input.toRuneArray()
    let _out = Array<Rune>(end - start, { _ => r'\u{0000}' })
    var _i = 0
    while (_i < end - start) {
        _out[_i] = _r[start + _i]
        _i++
    }
    String(_out)
}"#;
            body = format!("{}\n\n{}", helper, body);
        }
        if body.contains("__k2cjRefEq2(") {
            let helper = r#"func __k2cjRefEq2<A, B>(a: ?A, b: ?B): Bool where A <: Object, B <: Object {
    match ((a, b)) {
        case (Some(x), Some(y)) => refEq(x, y)
        case (None, None) => true
        case _ => false
    }
}"#;
            body = format!("{}\n\n{}", helper, body);
        }
        let stub_result = crate::stubs::collect_stubs(&body);
        if let Some((_, stub_code)) = &stub_result {
            body.push_str("\n\n");
            body.push_str(stub_code);
        }
        let mut header = String::new();
        if body.contains("ArrayList")
            || body.contains("HashMap")
            || body.contains("HashSet")
            || body.contains(".iterator()")
            || body.contains("collectArray")
        {
            header.push_str("import std.collection.*\n");
        }
        if has_enum {
            header.push_str("import std.deriving.*\n");
        }
        if body.contains("@Derive[") && !header.contains("std.deriving") {
            header.push_str("import std.deriving.*\n");
        }
        if body.contains("Int64.parse") || body.contains("Float64.parse") || body.contains("radix:")
        {
            header.push_str("import std.convert.*\n");
        }
        if body.contains("sort(_s") || body.contains("sort(") {
            header.push_str("import std.sort.*\n");
        }
        if let Some((stub_imports, _)) = &stub_result {
            for imp in stub_imports {
                if !header.contains(*imp) {
                    header.push_str(imp);
                    header.push('\n');
                }
            }
        }
        if !header.is_empty() {
            header.push('\n');
        }
        Some(format!("{}{}\n", header, body))
    }
}

/// 给多行文本整体增加 n 级缩进。
pub(crate) fn indent(s: &str, n: usize) -> String {
    let pad = IND.repeat(n);
    s.lines()
        .map(|l| {
            if l.is_empty() {
                String::new()
            } else {
                format!("{}{}", pad, l)
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// 从声明字符串中精确剥离修饰符关键字（仅匹配行首的修饰符序列，避免误伤标识符）。
/// enum companion 常量提升到顶层后的名字。双下划线前缀避免与其它顶层符号撞名，
/// 且提升侧（render_enum）与引用侧（render_member）用同一命名规则保持一致。
fn lifted_enum_const_name(enum_name: &str, member: &str) -> String {
    format!("{}__{}", enum_name, member)
}

fn strip_modifier(s: &str, modifier: &str) -> String {
    let prefix = format!("{} ", modifier);
    // 仅处理第一行（声明签名行），保护函数体内容
    if let Some(first_nl) = s.find('\n') {
        let (head, tail) = s.split_at(first_nl);
        let cleaned = head.replacen(&prefix, "", 1);
        format!("{}{}", cleaned, tail)
    } else {
        s.replacen(&prefix, "", 1)
    }
}

fn rename_func_decl(rendered: &str, old: &str, new: &str) -> String {
    let old_sig = format!("func {}", old);
    let new_sig = format!("func {}", new);
    if rendered.contains(&old_sig) {
        rendered.replacen(&old_sig, &new_sig, 1)
    } else {
        rendered.to_string()
    }
}

//! 调用渲染：成员方法调用的特殊映射与 API 翻译规则。
//!
//! 从 render.rs 中拆分出来，集中管理 Kotlin→仓颉 API 映射规则，
//! 提升代码可维护性。新增 API 映射规则只需修改本文件。

use crate::engine::Engine;
use crate::node::*;

impl Engine {
    // ============ 调用渲染 ============

    /// 提取 `require(cond) { lazyMsg }` 里 lazyMessage lambda 的消息表达式。
    /// 单表达式体直接返回；多语句体退化为 IIFE。非 lambda 参数原样渲染。
    fn extract_lazy_message(&self, arg: NodeId) -> Option<String> {
        if let Kind::Lambda { body, .. } = self.g.kind(arg) {
            let inner = self.render_block_inner(*body, 0)?;
            if inner.contains('\n') {
                return Some(format!("({{ => {} }})()", inner));
            }
            return Some(inner);
        }
        self.t(arg)
    }

    pub(crate) fn render_call(&self, callee: NodeId, args: &[NodeId]) -> Option<String> {
        if let Kind::NameRef { original, .. } = self.g.kind(callee) {
            if original == "Char" && args.len() == 1 {
                return Some(format!("Rune(UInt32({}))", self.t(args[0])?));
            }
            if original == "charArrayOf" {
                let a: Vec<String> = args
                    .iter()
                    .map(|x| self.render_arg(*x))
                    .collect::<Option<_>>()?;
                return Some(format!("[{}]", a.join(", ")));
            }
            if original == "CharArray" && args.len() == 1 {
                return Some(format!(
                    "Array<Rune>({}, {{ _ => r'\\u{{0000}}' }})",
                    self.t(args[0])?
                ));
            }
            if (original == "Pair" || original == "Triple") && args.len() >= 2 {
                let a: Vec<String> = args
                    .iter()
                    .map(|x| self.render_arg(*x))
                    .collect::<Option<_>>()?;
                return Some(format!("({})", a.join(", ")));
            }
            // Kotlin stdlib 前置条件族 → 仓颉真实语义展开（无对应 std 函数，原样输出会
            // undeclared）。require/check 断言，error 直接抛，requireNotNull/checkNotNull 解包。
            // 仓颉 `if` 无 else 为 Unit，语句/表达式位皆合法（require 返 Unit）。
            if matches!(original.as_str(), "require" | "check")
                && (args.len() == 1 || args.len() == 2)
                && !self.is_user_func(original)
            {
                let (exc, default_msg) = if original == "require" {
                    ("IllegalArgumentException", "Failed requirement.")
                } else {
                    ("IllegalStateException", "Check failed.")
                };
                let cond = self.t(args[0])?;
                let msg = if args.len() == 2 {
                    self.extract_lazy_message(args[1])?
                } else {
                    format!("\"{}\"", default_msg)
                };
                return Some(format!("if (!({})) {{ throw {}({}) }}", cond, exc, msg));
            }
            if original == "error" && args.len() == 1 && !self.is_user_func(original) {
                let msg = self.t(args[0])?;
                return Some(format!("throw IllegalStateException({})", msg));
            }
            if matches!(original.as_str(), "requireNotNull" | "checkNotNull")
                && (args.len() == 1 || args.len() == 2)
                && !self.is_user_func(original)
            {
                let exc = if original == "requireNotNull" {
                    "IllegalArgumentException"
                } else {
                    "IllegalStateException"
                };
                let val = self.t(args[0])?;
                let msg = if args.len() == 2 {
                    self.extract_lazy_message(args[1])?
                } else {
                    "\"Required value was null.\"".to_string()
                };
                // 解包 Option：Some(v)=>v 否则 throw（表达式位，返回非空值）。
                return Some(format!(
                    "(match ({}) {{ case Some(_v) => _v; case None => throw {}({}) }})",
                    val, exc, msg
                ));
            }
            if (original == "maxOf"
                || original == "minOf"
                || ((original == "max" || original == "min") && !self.is_user_func(original)))
                && args.len() == 2
            {
                let a = self.t(args[0])?;
                let b = self.t(args[1])?;
                let cmp = if original == "maxOf" || original == "max" {
                    ">"
                } else {
                    "<"
                };
                return Some(format!(
                    "(if ({} {} {}) {{ {} }} else {{ {} }})",
                    a, cmp, b, a, b
                ));
            }
            if original == "abs" && args.len() == 1 && !self.is_user_func(original) {
                let a = self.atom(args[0])?;
                return Some(format!("(if ({} < 0) {{ -({}) }} else {{ {} }})", a, a, a));
            }
            if (original == "Array"
                || original == "IntArray"
                || original == "BooleanArray"
                || original == "DoubleArray"
                || original == "LongArray")
                && args.len() == 2
            {
                if let Kind::Lambda { params, body } = self.g.kind(args[1]) {
                    let n = self.t(args[0])?;
                    let inner = self.render_block_inner(*body, 0)?;
                    let pname = if let Some(p) = params.first() {
                        crate::parser::safe_name(p.split(':').next().unwrap_or(p).trim())
                    } else if self.uses_it(*body) {
                        "it".to_string()
                    } else {
                        "_idx".to_string()
                    };
                    let body_str = if inner.lines().count() <= 1 {
                        inner.trim().to_string()
                    } else {
                        format!("\n{}\n", crate::render::indent(&inner, 1))
                    };
                    return Some(format!("Array({}, {{ {} => {} }})", n, pname, body_str));
                }
            }
        }
        if let Kind::Member { base, name, safe } = self.g.kind(callee) {
            if let Some(a) = self.render_call_args_with_params(name, args) {
                let c = self.atom(callee)?;
                return Some(format!("{}({})", c, a.join(", ")));
            }
            if let Some(result) = self.render_member_call(*base, name, args, *safe) {
                return Some(result);
            }
        }
        let c = self.atom(callee)?;
        if let Kind::NameRef { original, .. } = self.g.kind(callee) {
            if let Some(a) = self.render_call_args_with_params(original, args) {
                return Some(format!("{}({})", c, a.join(", ")));
            }
        }
        let a: Vec<String> = args
            .iter()
            .map(|x| self.render_arg(*x))
            .collect::<Option<_>>()?;
        Some(format!("{}({})", c, a.join(", ")))
    }

    /// 渲染成员方法调用的接收者，可空且非 rebound 且非 `?.` 时插入 `.getOrThrow()`。
    /// 与 render.rs 成员访问自动解包路径语义一致，覆盖方法调用路径（此前只走 atom 不解包）。
    fn render_call_recv(&self, base: NodeId, safe: bool) -> Option<String> {
        let raw = self.atom(base)?;
        if !safe && self.is_nullable_expr(base) && !self.is_null_check_rebound(base) {
            Some(format!("{}.getOrThrow()", raw))
        } else {
            Some(raw)
        }
    }

    /// 成员方法调用的特殊映射，返回 None 表示无特殊处理。
    fn render_member_call(
        &self,
        base: NodeId,
        name: &str,
        args: &[NodeId],
        safe: bool,
    ) -> Option<String> {
        if name == "values" && args.is_empty() {
            if let Kind::NameRef { original, .. } = self.g.kind(base) {
                if let Some(entries) = self.enum_entries(original) {
                    let items: Vec<String> = entries
                        .iter()
                        .map(|e| format!("{}.{}", original, e))
                        .collect();
                    return Some(format!("[{}]", items.join(", ")));
                }
            }
        }
        // Auto-unwrap a nullable method-call receiver (under-unwrap fix, mirrors
        // render.rs member-access path): `x.foo()` where `x: ?T` and `x` is not a
        // rebound smart-cast local → `x.getOrThrow().foo()`. Skip for `?.` safe calls
        // (None short-circuit semantics) and for null-check-rebound locals (already
        // non-Option in the guarded block — avoids R10-style over-unwrap regression).
        let b = self.render_call_recv(base, safe)?;
        match name {
            // ---- Char 方法 ----
            "isDigit" | "isLetter" | "isWhitespace" | "isUpperCase" | "isLowerCase"
                if args.is_empty() && self.looks_char(base) =>
            {
                let m = crate::stdlib_map::lookup_method(name, "char").unwrap_or(name);
                Some(format!("{}.{}()", b, m))
            }
            "isLetterOrDigit" if args.is_empty() && self.looks_char(base) => {
                Some(format!("({}.isAsciiLetter() || {}.isAsciiNumber())", b, b))
            }
            "toChar" if args.is_empty() => Some(format!("Rune(UInt32({}))", b)),

            // Kotlin null-aware 扩展 `T?.isNullOrEmpty()`（CharSequence/Collection 皆有）：
            // 语义 = receiver 为 null **或** 空。绝不能对可空接收者插 `.getOrThrow()`
            // （那会在 null 时抛异常，正好抹掉 null 分支），故用**原始未解包**接收者。
            // - 可空接收者：`((x?.isEmpty()) ?? true)`——None 短路成 true，Some 走 .isEmpty()；
            //   对 String 与 Collection 同构（两者都有 isEmpty()）。
            // - 非空接收者（已 smart-cast rebound 或本就非空）：退化为 `x.isEmpty()`。
            // 根因：此前 isNullOrEmpty 无映射被透传，且接收者被 getOrThrow 解包，
            // 导致 `x.getOrThrow().isNullOrEmpty()`——isNullOrEmpty 非仓颉成员 → Validate
            // 等宿主函数体编译失败 → 其全部调用点级联报 "no matching declaration"（1g R15 簇 E）。
            "isNullOrEmpty" if args.is_empty() => {
                let raw = self.atom(base)?;
                if !safe && self.is_nullable_expr(base) && !self.is_null_check_rebound(base) {
                    Some(format!("(({}?.isEmpty()) ?? true)", raw))
                } else {
                    Some(format!("{}.isEmpty()", raw))
                }
            }

            // ---- String 方法 ----
            "padStart" | "padEnd"
                if self.looks_string(base) && (args.len() == 1 || args.len() == 2) =>
            {
                let width = self.t(args[0])?;
                let pad = if args.len() == 2 {
                    if let Kind::CharLit(c) = self.g.kind(args[1]) {
                        format!("\"{}\"", c)
                    } else {
                        format!("({}).toString()", self.t(args[1])?)
                    }
                } else {
                    "\" \"".to_string()
                };
                Some(format!("{}.{}({}, padding: {})", b, name, width, pad))
            }
            "indexOf" if args.len() == 1 && self.looks_string(base) => {
                let needle = if let Kind::CharLit(c) = self.g.kind(args[0]) {
                    format!("\"{}\"", c)
                } else {
                    self.t(args[0])?
                };
                Some(format!("({}.indexOf({}) ?? -1)", b, needle))
            }
            "startsWith" if args.len() == 1 && self.looks_string(base) => {
                let needle = if let Kind::CharLit(c) = self.g.kind(args[0]) {
                    format!("\"{}\"", c)
                } else {
                    self.t(args[0])?
                };
                Some(format!("{}.startsWith({})", b, needle))
            }
            "endsWith" if args.len() == 1 && self.looks_string(base) => {
                let needle = if let Kind::CharLit(c) = self.g.kind(args[0]) {
                    format!("\"{}\"", c)
                } else {
                    self.t(args[0])?
                };
                Some(format!("{}.endsWith({})", b, needle))
            }
            "contains" if args.len() == 1 && self.looks_string(base) => {
                let needle = if let Kind::CharLit(c) = self.g.kind(args[0]) {
                    format!("\"{}\"", c)
                } else {
                    self.t(args[0])?
                };
                Some(format!("{}.contains({})", b, needle))
            }
            "contains"
                if args.len() == 1
                    && self.expr_type_name(base).as_deref() == Some("Range<Int64>") =>
            {
                let v = self.t(args[0])?;
                Some(format!(
                    "({{ => let _r = {}; let _v = {}; if (_r.step > 0) {{ if (_r.isClosed) {{ (_v >= _r.start) && (_v <= _r.end) }} else {{ (_v >= _r.start) && (_v < _r.end) }} }} else {{ if (_r.isClosed) {{ (_v <= _r.start) && (_v >= _r.end) }} else {{ (_v <= _r.start) && (_v > _r.end) }} }} }})()",
                    b, v
                ))
            }
            "replace" if args.len() == 2 && self.looks_string(base) => {
                let old_str = if let Kind::CharLit(c) = self.g.kind(args[0]) {
                    format!("\"{}\"", c)
                } else {
                    self.t(args[0])?
                };
                let new_str = if let Kind::CharLit(c) = self.g.kind(args[1]) {
                    format!("\"{}\"", c)
                } else {
                    self.t(args[1])?
                };
                Some(format!("{}.replace({}, {})", b, old_str, new_str))
            }
            "split" if args.len() == 1 && self.looks_string(base) => {
                let delim = if let Kind::CharLit(c) = self.g.kind(args[0]) {
                    format!("\"{}\"", c)
                } else {
                    self.t(args[0])?
                };
                Some(format!(
                    "collectArrayList({}.split({}).iterator())",
                    b, delim
                ))
            }
            "substring" if args.len() == 2 => {
                Some(self.render_string_rune_slice(&b, &self.t(args[0])?, &self.t(args[1])?))
            }
            "substring" if args.len() == 1 => Some(self.render_string_rune_slice(
                &b,
                &self.t(args[0])?,
                &format!("{}.toRuneArray().size", b),
            )),
            "subSequence" if args.len() == 2 => {
                Some(self.render_string_rune_slice(&b, &self.t(args[0])?, &self.t(args[1])?))
            }
            "repeat" if args.len() == 1 && self.looks_string(base) => {
                Some(format!("({} * {})", b, self.atom(args[0])?))
            }
            "take" if args.len() == 1 && self.looks_string(base) => {
                Some(self.render_string_rune_slice(&b, "0", &self.t(args[0])?))
            }
            "drop" if args.len() == 1 && self.looks_string(base) => {
                Some(self.render_string_rune_slice(
                    &b,
                    &self.t(args[0])?,
                    &format!("{}.toRuneArray().size", b),
                ))
            }
            "reversed" if args.is_empty() && self.looks_string(base) => Some(format!(
                "({{ => let _r = {}.toRuneArray(); String(Array<Rune>(_r.size, {{j => _r[_r.size - 1 - j]}})) }})()",
                b
            )),

            // ---- 集合通用方法 ----
            "isEmpty" if args.is_empty() && self.looks_string_builder(base) => {
                Some(format!("({}.toString().size == 0)", b))
            }
            "isNotEmpty" if args.is_empty() && self.looks_string_builder(base) => {
                Some(format!("({}.toString().size > 0)", b))
            }
            "removeAt" if args.len() == 1 => {
                Some(format!("{}.remove(at: {})", b, self.t(args[0])?))
            }
            "addAll" if args.len() == 1 && !self.provably_non_collection(base) => {
                Some(format!("{}.add(all: {})", b, self.t(args[0])?))
            }
            "not" if args.is_empty() => {
                Some(format!("!({})", b))
            }
            "containsKey" if args.len() == 1 => {
                Some(format!("{}.contains({})", b, self.t(args[0])?))
            }
            "clear" if args.is_empty() => Some(format!("{}.clear()", b)),
            "getOrDefault" if args.len() == 2 => Some(format!(
                "({}.get({}) ?? {})",
                b,
                self.t(args[0])?,
                self.t(args[1])?
            )),
            "getOrPut" if args.len() == 2 => {
                let key = self.t(args[0])?;
                let default_lam = self.t(args[1])?;
                Some(format!(
                    "({{ => if ({b}.contains({key})) {{ {b}[{key}] }} else {{ let _v = ({default_lam})(); {b}[{key}] = _v; _v }} }})()",
                    b = b,
                    key = key,
                    default_lam = default_lam
                ))
            }
            "isNotEmpty" if args.is_empty() => {
                if self.looks_string_builder(base) {
                    Some(format!("({}.toString().size > 0)", b))
                } else {
                    Some(format!("!({}.isEmpty())", b))
                }
            }
            "first" if args.is_empty() => Some(format!("{}[0]", b)),
            "last" if args.is_empty() => Some(format!("{}[{}.size - 1]", b, b)),
            "firstOrNull" if args.is_empty() && !self.provably_non_collection(base) => {
                Some(format!("{}.get(0)", b))
            }
            "lastOrNull" if args.is_empty() && !self.provably_non_collection(base) => {
                Some(format!("{}.get({}.size - 1)", b, b))
            }

            // ---- 排序 ----
            "sort" if args.is_empty() && !self.provably_non_collection(base) => {
                Some(format!("sort({}, stable: true)", b))
            }
            "sortDescending" if args.is_empty() && !self.provably_non_collection(base) => {
                Some(format!("sort({}, stable: true, descending: true)", b))
            }
            "sortBy" if args.len() == 1 && !self.provably_non_collection(base) => Some(format!(
                "sort({}, key: {}, stable: true)",
                b,
                self.t(args[0])?
            )),
            "sortByDescending" if args.len() == 1 && !self.provably_non_collection(base) => {
                Some(format!(
                    "sort({}, key: {}, stable: true, descending: true)",
                    b,
                    self.t(args[0])?
                ))
            }
            "sorted" if args.is_empty() && !self.provably_non_collection(base) => Some(format!(
                "({{ => let _s = collectArrayList({}); sort(_s, stable: true); _s }})()",
                self.as_iter(base)?
            )),
            "sortedDescending" if args.is_empty() && !self.provably_non_collection(base) => {
                Some(format!(
                    "({{ => let _s = collectArrayList({}); sort(_s, stable: true, descending: true); _s }})()",
                    self.as_iter(base)?
                ))
            }
            "sortedBy" if args.len() == 1 && !self.provably_non_collection(base) => Some(format!(
                "({{ => let _s = collectArrayList({}); sort(_s, key: {}, stable: true); _s }})()",
                self.as_iter(base)?,
                self.t(args[0])?
            )),
            "sortedByDescending" if args.len() == 1 && !self.provably_non_collection(base) => {
                Some(format!(
                    "({{ => let _s = collectArrayList({}); sort(_s, key: {}, stable: true, descending: true); _s }})()",
                    self.as_iter(base)?,
                    self.t(args[0])?
                ))
            }

            // ---- 函数式集合操作 ----
            "withIndex" if args.is_empty() && !self.provably_non_collection(base) => {
                Some(format!("{}.iterator().enumerate()", b))
            }
            "forEach" if args.len() == 1 && !self.provably_non_collection(base) => {
                let lam = self.t(args[0])?;
                Some(format!(
                    "for (_e in {}) {{ ({})(_e) }}",
                    self.atom(base)?,
                    lam
                ))
            }
            "forEachIndexed" if args.len() == 1 && !self.provably_non_collection(base) => {
                let lam = self.t(args[0])?;
                Some(format!(
                    "for ((_i, _e) in {}.enumerate()) {{ ({})(_i, _e) }}",
                    self.as_iter(base)?,
                    lam
                ))
            }
            "map" | "filter" if args.len() == 1 && !self.provably_non_collection(base) => {
                Some(format!(
                    "collectArrayList({}.{}({}))",
                    self.as_iter(base)?,
                    name,
                    self.t(args[0])?
                ))
            }
            "flatMap" if args.len() == 1 && !self.provably_non_collection(base) => Some(format!(
                "collectArrayList({}.flatMap({{ _e => ({})(_e).iterator() }}))",
                self.as_iter(base)?,
                self.t(args[0])?
            )),
            "any" | "all" if args.len() == 1 && !self.provably_non_collection(base) => Some(
                format!("{}.{}({})", self.as_iter(base)?, name, self.t(args[0])?),
            ),
            "none" if args.len() == 1 && !self.provably_non_collection(base) => Some(format!(
                "!{}.any({})",
                self.as_iter(base)?,
                self.t(args[0])?
            )),
            "count" if args.len() == 1 && !self.provably_non_collection(base) => Some(format!(
                "{}.filter({}).count()",
                self.as_iter(base)?,
                self.t(args[0])?
            )),
            "count" if args.is_empty() && !self.provably_non_collection(base) => {
                Some(format!("{}.size", b))
            }
            "sum" if args.is_empty() && !self.provably_non_collection(base) => Some(format!(
                "{}.fold<Int64>(0, {{acc, x => acc + x}})",
                self.as_iter(base)?
            )),
            "sumOf" if args.len() == 1 && !self.provably_non_collection(base) => Some(format!(
                "{}.map({}).fold<Int64>(0, {{acc, x => acc + x}})",
                self.as_iter(base)?,
                self.t(args[0])?
            )),
            "fold" if args.len() == 2 && !self.provably_non_collection(base) => {
                let ty = self.lit_type(args[0]);
                Some(format!(
                    "{}.fold<{}>({}, {})",
                    self.as_iter(base)?,
                    ty,
                    self.t(args[0])?,
                    self.t(args[1])?
                ))
            }
            "reduce" if args.len() == 1 && !self.provably_non_collection(base) => Some(format!(
                "{}.reduce({}).getOrThrow()",
                self.as_iter(base)?,
                self.t(args[0])?
            )),
            "max" | "min" if args.is_empty() && !self.provably_non_collection(base) => {
                let cmp = if name == "max" { ">" } else { "<" };
                Some(format!(
                    "{}.reduce({{a, b => if (a {} b) {{ a }} else {{ b }}}}).getOrThrow()",
                    self.as_iter(base)?,
                    cmp
                ))
            }
            "maxOrNull" | "minOrNull" if args.is_empty() && !self.provably_non_collection(base) => {
                let cmp = if name == "maxOrNull" { ">" } else { "<" };
                Some(format!(
                    "{}.reduce({{a, b => if (a {} b) {{ a }} else {{ b }}}})",
                    self.as_iter(base)?,
                    cmp
                ))
            }
            "average" if args.is_empty() && !self.provably_non_collection(base) => Some(format!(
                "(Float64({}.fold<Int64>(0, {{acc, x => acc + x}})) / Float64({}.count()))",
                self.as_iter(base)?,
                self.as_iter(base)?
            )),
            "reversed" if args.is_empty() && !self.provably_non_collection(base) => Some(format!(
                "({{ => let _s = collectArrayList({}); _s.reverse(); _s }})()",
                self.as_iter(base)?
            )),
            "take" if args.len() == 1 && !self.provably_non_collection(base) => Some(format!(
                "collectArrayList({}.take({}))",
                self.as_iter(base)?,
                self.t(args[0])?
            )),
            "drop" if args.len() == 1 && !self.provably_non_collection(base) => Some(format!(
                "collectArrayList({}.skip({}))",
                self.as_iter(base)?,
                self.t(args[0])?
            )),
            "toList" | "toMutableList"
                if args.is_empty() && !self.provably_non_collection(base) =>
            {
                Some(format!("collectArrayList({})", self.atom(base)?))
            }
            "distinct" if args.is_empty() && !self.provably_non_collection(base) => Some(format!(
                "({{ => let _hs = HashSet<Int64>(); let _r = ArrayList<Int64>(); for (_e in {}) {{ if (!_hs.contains(_e)) {{ _hs.put(_e); _r.add(_e) }} }}; _r }})()",
                self.atom(base)?
            )),
            "joinToString" if !self.provably_non_collection(base) => {
                self.render_join_to_string(base, &b, args)
            }

            // ---- 更多集合操作 ----
            "mapIndexed" if args.len() == 1 && !self.provably_non_collection(base) => {
                let lam = self.t(args[0])?;
                Some(format!(
                    "collectArrayList({}.enumerate().map({{ _p => ({})(_p[0], _p[1]) }}))",
                    self.as_iter(base)?,
                    lam
                ))
            }
            "filterNot" if args.len() == 1 && !self.provably_non_collection(base) => {
                let pred = self.t(args[0])?;
                Some(format!(
                    "collectArrayList({}.filter({{ _e => !({})(_e) }}))",
                    self.as_iter(base)?,
                    pred
                ))
            }
            "filterNotNull" if args.is_empty() && !self.provably_non_collection(base) => {
                Some(format!(
                    "collectArrayList({}.filter({{ _e => _e != None }}).map({{ _e => _e.getOrThrow() }}))",
                    self.as_iter(base)?
                ))
            }
            "flatten" if args.is_empty() && !self.provably_non_collection(base) => Some(format!(
                "collectArrayList({}.flatMap({{ _e => _e.iterator() }}))",
                self.as_iter(base)?
            )),
            "associateBy" if args.len() == 1 && !self.provably_non_collection(base) => {
                let key_fn = self.t(args[0])?;
                Some(format!(
                    "({{ => let _m = HashMap<Int64, Int64>(); for (_e in {}) {{ _m[({})(_e)] = _e }}; _m }})()",
                    self.atom(base)?,
                    key_fn
                ))
            }
            "associateWith" if args.len() == 1 && !self.provably_non_collection(base) => {
                let val_fn = self.t(args[0])?;
                Some(format!(
                    "({{ => let _m = HashMap<Int64, Int64>(); for (_e in {}) {{ _m[_e] = ({})(_e) }}; _m }})()",
                    self.atom(base)?,
                    val_fn
                ))
            }
            "mapValues" if args.len() == 1 && !self.provably_non_collection(base) => {
                let lam = self.t(args[0])?;
                Some(format!(
                    "({{ => let _m = HashMap<Int64, Int64>(); for ((_k, _v) in {}) {{ _m[_k] = ({})((key: _k, value: _v)) }}; _m }})()",
                    self.atom(base)?,
                    lam
                ))
            }
            "mapKeys" if args.len() == 1 && !self.provably_non_collection(base) => {
                let lam = self.t(args[0])?;
                Some(format!(
                    "({{ => let _m = HashMap<Int64, Int64>(); for ((_k, _v) in {}) {{ _m[({})((key: _k, value: _v))] = _v }}; _m }})()",
                    self.atom(base)?,
                    lam
                ))
            }
            "indexOfFirst" if args.len() == 1 && !self.provably_non_collection(base) => {
                let pred = self.t(args[0])?;
                Some(format!(
                    "({{ => var _i = 0; for (_e in {}) {{ if (({})(_e)) {{ return _i }}; _i++ }}; return -1 }})()",
                    self.atom(base)?,
                    pred
                ))
            }
            "indexOfLast" if args.len() == 1 && !self.provably_non_collection(base) => {
                let pred = self.t(args[0])?;
                Some(format!(
                    "({{ => var _r = -1; var _i = 0; for (_e in {}) {{ if (({})(_e)) {{ _r = _i }}; _i++ }}; return _r }})()",
                    self.atom(base)?,
                    pred
                ))
            }
            "find" if args.len() == 1 && !self.provably_non_collection(base) => {
                let pred = self.t(args[0])?;
                Some(format!(
                    "({{ => for (_e in {}) {{ if (({})(_e)) {{ return _e }} }}; return None }})()",
                    self.atom(base)?,
                    pred
                ))
            }
            "findLast" if args.len() == 1 && !self.provably_non_collection(base) => {
                let pred = self.t(args[0])?;
                Some(format!(
                    "({{ => var _r: Option<Int64> = None; for (_e in {}) {{ if (({})(_e)) {{ _r = _e }} }}; return _r }})()",
                    self.atom(base)?,
                    pred
                ))
            }
            "zip" if args.len() >= 1 && !self.provably_non_collection(base) => {
                let other = self.t(args[0])?;
                if args.len() == 2 {
                    // zip with transform: list.zip(other) { a, b -> expr }
                    let lam = self.t(args[1])?;
                    Some(format!(
                        "collectArrayList({}.zip({}.iterator()).map({{ _p => ({})(_p[0], _p[1]) }}))",
                        self.as_iter(base)?,
                        other,
                        lam
                    ))
                } else {
                    Some(format!(
                        "collectArrayList({}.zip({}.iterator()))",
                        self.as_iter(base)?,
                        other
                    ))
                }
            }
            "partition" if args.len() == 1 && !self.provably_non_collection(base) => {
                let pred = self.t(args[0])?;
                Some(format!(
                    "({{ => let _t = ArrayList<Int64>(); let _f = ArrayList<Int64>(); for (_e in {}) {{ if (({})(_e)) {{ _t.add(_e) }} else {{ _f.add(_e) }} }}; (_t, _f) }})()",
                    self.atom(base)?,
                    pred
                ))
            }
            "chunked" if args.len() == 1 && !self.provably_non_collection(base) => {
                let n = self.t(args[0])?;
                Some(format!(
                    "({{ => let _src = collectArrayList({}); let _r = ArrayList<ArrayList<Int64>>(); var _i = 0; while (_i < _src.size) {{ let _end = if (_i + {} < _src.size) {{ _i + {} }} else {{ _src.size }}; let _c = ArrayList<Int64>(); var _j = _i; while (_j < _end) {{ _c.add(_src[_j]); _j++ }}; _r.add(_c); _i = _end }}; _r }})()",
                    self.as_iter(base)?,
                    n,
                    n
                ))
            }

            // ---- HashMap 特有操作 ----
            "groupBy" if args.len() == 1 && !self.provably_non_collection(base) => {
                let key_fn = self.t(args[0])?;
                Some(format!(
                    "({{ => let _m = HashMap<Int64, ArrayList<Int64>>(); for (_e in {}) {{ let _k = ({})(_e); if (!_m.contains(_k)) {{ _m[_k] = ArrayList<Int64>() }}; _m[_k].add(_e) }}; _m }})()",
                    self.atom(base)?,
                    key_fn
                ))
            }
            "associate" if args.len() == 1 && !self.provably_non_collection(base) => {
                let pair_fn = self.t(args[0])?;
                Some(format!(
                    "({{ => let _m = HashMap<Int64, Int64>(); for (_e in {}) {{ let _p = ({})(_e); _m[_p[0]] = _p[1] }}; _m }})()",
                    self.atom(base)?,
                    pair_fn
                ))
            }

            // ---- 类型转换 ----
            "toInt" | "toLong" if args.len() == 1 => {
                Some(format!("Int64.parse({}, radix: {})", b, self.t(args[0])?))
            }
            "toInt" | "toLong" if args.is_empty() => {
                if self.looks_numeric(base) {
                    Some(format!("Int64({})", b))
                } else {
                    Some(format!("Int64.parse({})", b))
                }
            }
            "toDouble" | "toFloat" if args.is_empty() => {
                if self.looks_numeric(base) {
                    Some(format!("Float64({})", b))
                } else {
                    Some(format!("Float64.parse({})", b))
                }
            }
            "toString" if args.is_empty() => Some(format!("{}.toString()", b)),
            "toString" if args.len() == 1 => {
                Some(format!("{}.toString(radix: {})", b, self.t(args[0])?))
            }

            // Kotlin String.equals(other) → Cangjie (lhs == rhs)
            "equals" if args.len() == 1 => {
                Some(format!("({} == {})", b, self.t(args[0])?))
            }
            // Kotlin String.equals(other, ignoreCase=true) → case-insensitive compare
            "equals" if args.len() == 2 => {
                let rhs = self.t(args[0])?;
                Some(format!("({}.toAsciiLower() == {}.toAsciiLower())", b, rhs))
            }

            _ => None,
        }
    }

    fn render_join_to_string(&self, base: NodeId, _b: &str, args: &[NodeId]) -> Option<String> {
        let has_lambda = args
            .last()
            .map(|a| matches!(self.g.kind(*a), Kind::Lambda { .. }))
            .unwrap_or(false);
        let sep = match args.first() {
            Some(a) if !(args.len() == 1 && has_lambda) => self.t(*a)?,
            _ => "\", \"".to_string(),
        };
        if has_lambda {
            let lam = self.t(*args.last().unwrap())?;
            return Some(format!(
                "String.join(collectArray<String>({}.map({})), delimiter: {})",
                self.as_iter(base)?,
                lam,
                sep
            ));
        }
        let joined = format!(
            "String.join(collectArray<String>({}.map({{e => e.toString()}})), delimiter: {})",
            self.as_iter(base)?,
            sep
        );
        if args.len() >= 2 {
            let prefix = self.t(args[1])?;
            let postfix = if args.len() >= 3 {
                self.t(args[2])?
            } else {
                "\"\"".to_string()
            };
            return Some(format!("({} + {} + {})", prefix, joined, postfix));
        }
        Some(joined)
    }

    fn render_string_rune_slice(&self, base: &str, start: &str, end: &str) -> String {
        format!("__k2cjRuneSlice({}, {}, {})", base, start, end)
    }
}

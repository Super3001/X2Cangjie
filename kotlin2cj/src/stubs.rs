//! Kotlin stdlib 类型面 stub 注入：为仓颉侧缺失的 Kotlin/java 标准库类型
//! 提供最小可编译替身（薄适配封装或 stub）。
//!
//! 机制（与 `__k2cjRuneSlice` 运行时辅助函数注入一脉相承，做成数据驱动表）：
//! - 每个 `StubDef` 声明：提供的顶层类型名（provides）、触发注入的标识符
//!   （markers，词边界匹配）、需要的 import 行、仓颉源码；
//! - 渲染完成后扫描输出代码体，命中 marker 且输出中没有同名用户定义时注入；
//! - 单文件模式由 `render_program` 追加到文件尾；项目模式由 `convert_project`
//!   汇总写入独立的 `k2cj_stubs.cj`（同包共享，避免每文件重复定义）。
//!
//! 铁律：stub 面最小化——只覆盖测量语料（ksoup 等）实际调用的方法。

pub struct StubDef {
    /// 该 stub 提供的顶层类型/别名名（用于“用户已自定义同名类型则跳过”守卫）。
    pub provides: &'static [&'static str],
    /// 触发注入的标识符（任一在代码体中以词边界形式出现即注入）。
    pub markers: &'static [&'static str],
    /// 需要的 import 行。
    pub imports: &'static [&'static str],
    /// 注入的仓颉源码。
    pub code: &'static str,
}

/// Kotlin `Regex` → std.regex 薄适配封装（含 RegexOption / MatchResult / String 扩展）。
const REGEX_STUB: StubDef = StubDef {
    provides: &["Regex", "RegexOption", "MatchResult"],
    markers: &["Regex", "RegexOption", "toRegex"],
    imports: &[
        "import std.regex.Regex as StdRegex",
        "import std.regex.RegexFlag",
        "import std.regex.MatchData as StdMatchData",
        "import std.collection.*",
    ],
    code: r#"public enum RegexOption <: Hashable & Equatable<RegexOption> {
    IGNORE_CASE | MULTILINE
    public func hashCode(): Int64 {
        match (this) {
            case IGNORE_CASE => 1
            case MULTILINE => 2
        }
    }
    public operator func ==(that: RegexOption): Bool { this.hashCode() == that.hashCode() }
    public operator func !=(that: RegexOption): Bool { !(this == that) }
}

public class MatchResult {
    public let value: String
    public let groupValues: Array<String>
    public let first: Int64
    public let last: Int64
    init(m: StdMatchData) {
        this.value = m.matchString()
        let p = m.matchPosition()
        this.first = p.start
        this.last = p.end
        let n = m.groupCount()
        this.groupValues = Array<String>(n + 1, { i => try { m.matchString(i) } catch (_: Exception) { "" } })
    }
}

func __k2cjBuildStdRegex(pattern: String, options: HashSet<RegexOption>): StdRegex {
    let ic = options.contains(RegexOption.IGNORE_CASE)
    let ml = options.contains(RegexOption.MULTILINE)
    if (ic && ml) { return StdRegex(pattern, RegexFlag.IgnoreCase, RegexFlag.MultiLine) }
    if (ic) { return StdRegex(pattern, RegexFlag.IgnoreCase) }
    if (ml) { return StdRegex(pattern, RegexFlag.MultiLine) }
    return StdRegex(pattern)
}

public class Regex {
    public let pattern: String
    let _re: StdRegex
    public init(pattern: String) {
        this.pattern = pattern
        this._re = StdRegex(pattern)
    }
    public init(pattern: String, option: RegexOption) {
        this.pattern = pattern
        this._re = __k2cjBuildStdRegex(pattern, HashSet<RegexOption>([option]))
    }
    public init(pattern: String, options: HashSet<RegexOption>) {
        this.pattern = pattern
        this._re = __k2cjBuildStdRegex(pattern, options)
    }
    public func matches(input: String): Bool { this._re.matches(input) }
    public func containsMatchIn(input: String): Bool { this._re.find(input).isSome() }
    public func find(input: String): ?MatchResult {
        if (let Some(m) <- this._re.find(input, group: true)) { return Some(MatchResult(m)) }
        return None
    }
    public func matchEntire(input: String): ?MatchResult {
        if (let Some(m) <- this._re.find(input, group: true)) {
            let p = m.matchPosition()
            if (p.start == 0 && p.end == input.size) { return Some(MatchResult(m)) }
        }
        return None
    }
    public func findAll(input: String): ArrayList<MatchResult> {
        let out = ArrayList<MatchResult>()
        for (m in this._re.findAll(input, group: true)) { out.add(MatchResult(m)) }
        return out
    }
    public func replace(input: String, replacement: String): String { this._re.replaceAll(input, replacement) }
    public func replaceFirst(input: String, replacement: String): String { this._re.replace(input, replacement) }
    public func split(input: String): Array<String> { this._re.split(input) }
    public func toString(): String { this.pattern }
}

extend String {
    public func toRegex(): Regex { Regex(this) }
    public func matches(regex: Regex): Bool { regex.matches(this) }
    public func replaceFirst(regex: Regex, replacement: String): String { regex.replaceFirst(this, replacement) }
    public func replace(regex: Regex, replacement: String): String { regex.replace(this, replacement) }
    public func replace(regex: Regex, transform: (MatchResult) -> String): String {
        let sb = StringBuilder()
        var last = 0
        for (m in regex.findAll(this)) {
            sb.append(this[last..m.first])
            sb.append(transform(m))
            last = m.last
        }
        sb.append(this[last..this.size])
        return sb.toString()
    }
}"#,
};

/// Kotlin 反射 `KClass<T>` 最小 stub（`X::class` 渲染为 `KClass<X>()`）。
const KCLASS_STUB: StubDef = StubDef {
    provides: &["KClass"],
    markers: &["KClass"],
    imports: &[],
    code: r#"public class KClass<T> {
    public let simpleName: ?String
    public init() { this.simpleName = None }
    public init(name: String) { this.simpleName = Some(name) }
    public func isInstance(obj: Any): Bool { obj is T }
}"#,
};

/// java.io 风格字符流 Reader / StringReader 最小 stub。
const READER_STUB: StubDef = StubDef {
    provides: &["Reader", "StringReader"],
    markers: &["Reader", "StringReader"],
    imports: &[],
    code: r#"public open class Reader {
    public open func read(buffer: Array<Rune>, offset!: Int64, length!: Int64): Int64 {
        let _ = (buffer, offset, length)
        return -1
    }
    public open func read(): Int64 { -1 }
    public open func close(): Unit {}
}

public class StringReader <: Reader {
    let _runes: Array<Rune>
    var _pos: Int64 = 0
    public init(s: String) { this._runes = s.toRuneArray() }
    public override func read(buffer: Array<Rune>, offset!: Int64, length!: Int64): Int64 {
        if (this._pos >= this._runes.size) { return -1 }
        var n = length
        if (n > this._runes.size - this._pos) { n = this._runes.size - this._pos }
        var i = 0
        while (i < n) {
            buffer[offset + i] = this._runes[this._pos + i]
            i++
        }
        this._pos += n
        return n
    }
    public override func read(): Int64 {
        if (this._pos >= this._runes.size) { return -1 }
        let c = this._runes[this._pos]
        this._pos++
        return Int64(UInt32(c))
    }
}"#,
};

/// Kotlin `Sequence<T>` → 基于 Iterable 的最小接口 + asSequence 扩展。
const SEQUENCE_STUB: StubDef = StubDef {
    provides: &["Sequence"],
    markers: &["Sequence", "asSequence"],
    imports: &["import std.collection.*"],
    code: r#"public interface Sequence<T> <: Iterable<T> {}

class __K2cjSeqWrap<T> <: Sequence<T> {
    let _f: () -> Iterator<T>
    init(f: () -> Iterator<T>) { this._f = f }
    public func iterator(): Iterator<T> { this._f() }
}

extend<T> Iterator<T> {
    public func asSequence(): Sequence<T> { __K2cjSeqWrap<T>({ => this }) }
}

extend<T> ArrayList<T> {
    public func asSequence(): Sequence<T> { __K2cjSeqWrap<T>({ => this.iterator() }) }
}"#,
};

/// Kotlin `MutableIterator` / `MutableListIterator` 最小 stub
/// （仓颉 Iterator 是抽象类，不能被 interface 继承，故用抽象类）。
const MUTABLE_ITERATOR_STUB: StubDef = StubDef {
    provides: &["MutableIterator", "MutableListIterator"],
    markers: &["MutableIterator", "MutableListIterator"],
    imports: &[],
    code: r#"public abstract class MutableIterator<T> <: Iterator<T> {
    public open func remove(): Unit {}
}

public abstract class MutableListIterator<T> <: MutableIterator<T> {}"#,
};

/// Kotlin `ByteArray` 类型别名（类型位由 map_type 映射，别名兜底 extend 目标位等）。
const BYTE_ARRAY_STUB: StubDef = StubDef {
    provides: &["ByteArray"],
    markers: &["ByteArray"],
    imports: &[],
    code: "public type ByteArray = Array<Byte>",
};

/// Kotlin `IntArray` 类型别名（同上兜底）。
const INT_ARRAY_STUB: StubDef = StubDef {
    provides: &["IntArray"],
    markers: &["IntArray"],
    imports: &[],
    code: "public type IntArray = Array<Int64>",
};

/// java.nio 风格 Charset / Charsets / CharsetEncoder 最小 stub。
const CHARSET_STUB: StubDef = StubDef {
    provides: &["Charset", "Charsets", "CharsetEncoder"],
    markers: &["Charset", "Charsets", "CharsetEncoder"],
    imports: &[],
    code: r#"public class Charset <: Equatable<Charset> {
    let _name: String
    public init(name: String) { this._name = name }
    public func name(): String { this._name }
    public func displayName(): String { this._name }
    public func newEncoder(): CharsetEncoder { CharsetEncoder(this) }
    public operator func ==(that: Charset): Bool { this._name == that._name }
    public operator func !=(that: Charset): Bool { this._name != that._name }
    public func toString(): String { this._name }
}

public class CharsetEncoder {
    let _cs: Charset
    public init(charset: Charset) { this._cs = charset }
    public func charset(): Charset { this._cs }
    public func canEncode(c: Rune): Bool {
        let n = this._cs.name()
        if (n == "US-ASCII" || n == "ascii" || n == "ASCII") { return UInt32(c) < 128 }
        if (n == "ISO-8859-1" || n == "latin-1") { return UInt32(c) < 256 }
        return true
    }
}

public class Charsets {
    public static let UTF8: Charset = Charset("UTF-8")
    public static let UTF_8: Charset = Charset("UTF-8")
    public static func forName(name: String): Charset { Charset(name) }
}"#,
};

/// Kotlin `Appendable` 接口 stub（StringBuilder 通过空扩展实现）。
const APPENDABLE_STUB: StubDef = StubDef {
    provides: &["Appendable"],
    markers: &["Appendable"],
    imports: &[],
    code: r#"public interface Appendable {
    func append(value: Rune): Unit
    func append(value: String): Unit
}

extend StringBuilder <: Appendable {}"#,
};

pub static STUBS: &[StubDef] = &[
    REGEX_STUB,
    KCLASS_STUB,
    READER_STUB,
    SEQUENCE_STUB,
    MUTABLE_ITERATOR_STUB,
    BYTE_ARRAY_STUB,
    INT_ARRAY_STUB,
    CHARSET_STUB,
    APPENDABLE_STUB,
];

/// 词边界匹配：`word` 在 `body` 中出现且前后均非标识符字符。
fn contains_word(body: &str, word: &str) -> bool {
    let bytes = body.as_bytes();
    let mut start = 0;
    while let Some(pos) = body[start..].find(word) {
        let abs = start + pos;
        let before_ok = abs == 0 || {
            let c = bytes[abs - 1];
            !(c.is_ascii_alphanumeric() || c == b'_')
        };
        let after = abs + word.len();
        let after_ok = after >= bytes.len() || {
            let c = bytes[after];
            !(c.is_ascii_alphanumeric() || c == b'_')
        };
        if before_ok && after_ok {
            return true;
        }
        start = abs + word.len().max(1);
    }
    false
}

/// 用户代码是否已自定义了同名顶层类型（class/interface/enum/type）。
fn defines_type(body: &str, name: &str) -> bool {
    for kw in ["class", "interface", "enum", "type"] {
        let pat = format!("{} {}", kw, name);
        let mut start = 0;
        while let Some(pos) = body[start..].find(&pat) {
            let abs = start + pos;
            // 词边界：pat 之后必须是非标识符字符（避免 `class Readers` 误判 `Reader`）
            let after = abs + pat.len();
            let after_ok = after >= body.len() || {
                let c = body.as_bytes()[after];
                !(c.is_ascii_alphanumeric() || c == b'_')
            };
            // pat 之前必须是行首或空白（避免命中字符串/注释里的内容的概率）
            let before_ok = abs == 0 || {
                let c = body.as_bytes()[abs - 1];
                c == b' ' || c == b'\n' || c == b'\t'
            };
            if after_ok && before_ok {
                return true;
            }
            start = abs + pat.len();
        }
    }
    false
}

/// 扫描已渲染的代码体，返回需要注入的 (import 行, stub 源码)。
/// 没有任何 stub 命中时返回 None。
pub fn collect_stubs(body: &str) -> Option<(Vec<&'static str>, String)> {
    let mut imports: Vec<&'static str> = Vec::new();
    let mut codes: Vec<&'static str> = Vec::new();
    for stub in STUBS {
        let hit = stub.markers.iter().any(|m| contains_word(body, m));
        if !hit {
            continue;
        }
        let user_defined = stub.provides.iter().any(|p| defines_type(body, p));
        if user_defined {
            continue;
        }
        for imp in stub.imports {
            if !imports.contains(imp) {
                imports.push(imp);
            }
        }
        codes.push(stub.code);
    }
    if codes.is_empty() {
        None
    } else {
        Some((imports, codes.join("\n\n")))
    }
}

package target_1g

import std.collection.*

func __k2cjRuneSlice(input: String, start: Int64, end: Int64): String {
    let _r = input.toRuneArray()
    let _out = Array<Rune>(end - start, { _ => r'\u{0000}' })
    var _i = 0
    while (_i < end - start) {
        _out[_i] = _r[start + _i]
        _i++
    }
    String(_out)
}

abstract class Evaluator {
    public open func asPredicate(root: Element): (Element) -> Bool {
        return { element => matches(root, element) }
    }
    public open func asNodePredicate(root: Element): (Node) -> Bool {
        return { node: Node => matches(root, node) }
    }
    public func matches(root: Element, element: Element): Bool
    public open func matches(root: Element, node: Node): Bool {
        if ((node is Element)) {
            return matches(root, node)
        } else if ((node is LeafNode) && wantsNodes()) {
            return matches(root, node)
        }
        return false
    }
    public open func matches(root: Element, leafNode: LeafNode): Bool {
        return false
    }
    public open func wantsNodes(): Bool {
        return false
    }
    public open func reset() {}
    public open func cost(): Int64 {
        return 5
    }
}

class Tag <: Evaluator & ToString {
    let tagName: String
    init(tagName: String) {
        this.tagName = tagName
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.nameIs(tagName)
    }
    public open override func cost(): Int64 {
        return 1
    }
    public open override func toString(): String {
        return tagName
    }
}

class TagStartsWith <: Evaluator & ToString {
    let tagName: String
    init(tagName: String) {
        this.tagName = tagName
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.normalName().startsWith(tagName)
    }
    public open override func toString(): String {
        return "${tagName}|*"
    }
}

class TagEndsWith <: Evaluator & ToString {
    let tagName: String
    init(tagName: String) {
        this.tagName = tagName
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.normalName().endsWith(tagName)
    }
    public open override func toString(): String {
        return "*|${tagName}"
    }
}

class Id <: Evaluator & ToString {
    let id: String
    init(id: String) {
        this.id = id
    }
    public open override func matches(root: Element, element: Element): Bool {
        return id == element.id()
    }
    public open override func cost(): Int64 {
        return 2
    }
    public open override func toString(): String {
        return "#${id}"
    }
}

class Class <: Evaluator & ToString {
    let className: String
    init(className: String) {
        this.className = className
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.hasClass(className)
    }
    public open override func cost(): Int64 {
        return 8
    }
    public open override func toString(): String {
        return ".${className}"
    }
}

class Attribute <: Evaluator & ToString {
    let key: String
    init(key: String) {
        this.key = key
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.hasAttr(key)
    }
    public open override func cost(): Int64 {
        return 2
    }
    public open override func toString(): String {
        return "[${key}]"
    }
}

class AttributeStarting <: Evaluator & ToString {
    init(keyPrefix: String) {
        this.keyPrefix = lowerCase(keyPrefix)
    }
    let keyPrefix: String
    public open override func matches(root: Element, element: Element): Bool {
        let values: ArrayList<com.fleeksoft.ksoup.nodes.Attribute> = element.attributes().asList()
        for (attribute in values) {
            if (lowerCase(attribute.key).startsWith(keyPrefix)) {
                return true
            }
        }
        return false
    }
    public open override func cost(): Int64 {
        return 6
    }
    public open override func toString(): String {
        return "[^${keyPrefix}]"
    }
}

class AttributeWithValue <: AttributeKeyPair & ToString {
    init(key: String, value: String) {
        super(key, value)
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.hasAttr(key) && (value.toAsciiLower() == element.attr(key).toAsciiLower())
    }
    public open override func cost(): Int64 {
        return 3
    }
    public open override func toString(): String {
        return "[${key}=${value}]"
    }
}

class AttributeWithValueNot <: AttributeKeyPair & ToString {
    init(key: String, value: String) {
        super(key, value)
    }
    public open override func matches(root: Element, element: Element): Bool {
        return !(value.toAsciiLower() == element.attr(key).toAsciiLower())
    }
    public open override func cost(): Int64 {
        return 3
    }
    public open override func toString(): String {
        return "[${key}!=${value}]"
    }
}

class AttributeWithValueStarting <: AttributeKeyPair & ToString {
    init(key: String, value: String) {
        super(key, value)
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.hasAttr(key) && lowerCase(element.attr(key)).startsWith(value)
    }
    public open override func cost(): Int64 {
        return 4
    }
    public open override func toString(): String {
        return "[${key}^=${value}]"
    }
}

class AttributeWithValueEnding <: AttributeKeyPair & ToString {
    init(key: String, value: String) {
        super(key, value)
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.hasAttr(key) && lowerCase(element.attr(key)).endsWith(value)
    }
    public open override func cost(): Int64 {
        return 4
    }
    public open override func toString(): String {
        return "[${key}$=${value}]"
    }
}

class AttributeWithValueContaining <: AttributeKeyPair & ToString {
    init(key: String, value: String) {
        super(key, value)
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.hasAttr(key) && lowerCase(element.attr(key)).contains(value)
    }
    public open override func cost(): Int64 {
        return 6
    }
    public open override func toString(): String {
        return "[${key}*=${value}]"
    }
}

class AttributeWithValueMatching <: Evaluator & ToString {
    var regex: Regex
    init(key: ?String, regex: Regex) {
        this.regex = regex
        this.key = normalize(key)
    }
    var key: String
    public open override func matches(root: Element, element: Element): Bool {
        return element.hasAttr(key) && (({ => for (_e in regex) { if ((element.attr(key))(_e)) { return _e } }; return None })().isSome())
    }
    public open override func cost(): Int64 {
        return 8
    }
    public open override func toString(): String {
        return "[${key}~=${regex.pattern}]"
    }
}

abstract class AttributeKeyPair <: Evaluator {
    init(key: String, value: String) {
        var resultValue = value
        Validate.notEmpty(key)
        this.key = normalize(key)
        let quoted = (resultValue.startsWith("'") && resultValue.endsWith("'")) || (resultValue.startsWith("\"") && resultValue.endsWith("\""))
        if (quoted) {
            Validate.isTrue(value.toRuneArray().size > 1, "Quoted value must have content")
            resultValue = __k2cjRuneSlice(value, 1, resultValue.toRuneArray().size - 1)
        }
        this.value = lowerCase(resultValue)
    }
    var key: String
    var value: String
}

class AllElements <: Evaluator & ToString {
    public open override func matches(root: Element, element: Element): Bool {
        return true
    }
    public open override func cost(): Int64 {
        return 10
    }
    public open override func toString(): String {
        return "*"
    }
}

class IndexLessThan <: IndexEvaluator & ToString {
    init(index: Int64) {
        super(index)
    }
    public open override func matches(root: Element, element: Element): Bool {
        return (root != element) && (element.elementSiblingIndex() < index)
    }
    public open override func toString(): String {
        return ":lt(${index})"
    }
}

class IndexGreaterThan <: IndexEvaluator & ToString {
    init(index: Int64) {
        super(index)
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.elementSiblingIndex() > index
    }
    public open override func toString(): String {
        return ":gt(${index})"
    }
}

class IndexEquals <: IndexEvaluator & ToString {
    init(index: Int64) {
        super(index)
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.elementSiblingIndex() == index
    }
    public open override func toString(): String {
        return ":eq(${index})"
    }
}

class IsLastChild <: Evaluator & ToString {
    public open override func matches(root: Element, element: Element): Bool {
        let p: ?Element = element.parent()
        return ((p.isSome()) && !(p is Document)) && (element == p.getOrThrow().lastElementChild())
    }
    public open override func toString(): String {
        return ":last-child"
    }
}

class IsFirstOfType <: IsNthOfType & ToString {
    init() {
        super(0, 1)
    }
    public open override func toString(): String {
        return ":first-of-type"
    }
}

class IsLastOfType <: IsNthLastOfType & ToString {
    init() {
        super(0, 1)
    }
    public open override func toString(): String {
        return ":last-of-type"
    }
}

abstract class CssNthEvaluator <: Evaluator & ToString {
    let a: Int64
    let b: Int64
    init(a: Int64, b: Int64) {
        this.a = a
        this.b = b
    }
    init(offset: Int64) {
        this(0)
    }
    public open override func matches(root: Element, element: Element): Bool {
        let parent = element.parent() ?? return
        false
        if ((parent is Document)) {
            return false
        }
        let pos = calculatePosition(root, element)
        return if (a == 0) {
            pos == b
        } else {
            (((pos - b) * a) >= 0) && (((pos - b) % a) == 0)
        }
    }
    public open override func toString(): String {
        let pseudo = getPseudoClass()
        return if (a == 0) {
            ":${pseudo}(${b})"
        } else if (b == 0) {
            ":${pseudo}(${a}n)"
        } else {
            let sign = if (b >= 0) {
                "+${b}"
            } else {
                "${b}"
            }
            ":${pseudo}(${a}n${sign})"
        }
    }
    public func getPseudoClass(): String
    public func calculatePosition(root: Element, element: Element): Int64
}

class IsNthChild <: CssNthEvaluator {
    init(a: Int64, b: Int64) {
        super(a, b)
    }
    public open override func calculatePosition(root: Element, element: Element): Int64 {
        return element.elementSiblingIndex() + 1
    }
    public open override func getPseudoClass(): String {
        return "nth-child"
    }
}

class IsNthLastChild <: CssNthEvaluator {
    init(a: Int64, b: Int64) {
        super(a, b)
    }
    public open override func calculatePosition(root: Element, element: Element): Int64 {
        if (element.parent().isNone()) {
            return 0
        }
        return element.parent().getOrThrow().childrenSize() - element.elementSiblingIndex()
    }
    public open override func getPseudoClass(): String {
        return "nth-last-child"
    }
}

open class IsNthOfType <: CssNthEvaluator {
    init(a: Int64, b: Int64) {
        super(a, b)
    }
    public open override func calculatePosition(root: Element, element: Element): Int64 {
        let parent = element.parent() ?? return
        0
        var pos = 0
        let size = parent.childNodeSize()
        for (i in 0..size) {
            let node = parent.childNode(i)
            if (node.normalName() == element.normalName()) {
                pos += 1
            }
            if (node == element) {
                break
            }
        }
        return pos
    }
    public open override func getPseudoClass(): String {
        return "nth-of-type"
    }
}

open class IsNthLastOfType <: CssNthEvaluator {
    init(a: Int64, b: Int64) {
        super(a, b)
    }
    public open override func calculatePosition(root: Element, element: Element): Int64 {
        let parent = element.parent() ?? return
        0
        var pos = 0
        var next: ?Element = element
        while (next.isSome()) {
            if (next.getOrThrow().normalName() == element.normalName()) {
                pos += 1
            }
            next = next.getOrThrow().nextElementSibling()
        }
        return pos
    }
    public open override func getPseudoClass(): String {
        return "nth-last-of-type"
    }
}

class IsFirstChild <: Evaluator & ToString {
    public open override func matches(root: Element, element: Element): Bool {
        let p: ?Element = element.parent()
        return ((p.isSome()) && !(p is Document)) && (element == p.getOrThrow().firstElementChild())
    }
    public open override func toString(): String {
        return ":first-child"
    }
}

class IsRoot <: Evaluator & ToString {
    public open override func matches(root: Element, element: Element): Bool {
        let r: ?Element = if ((root is Document)) {
            root.firstElementChild()
        } else {
            root
        }
        return element == r
    }
    public open override func cost(): Int64 {
        return 1
    }
    public open override func toString(): String {
        return ":root"
    }
}

class IsOnlyChild <: Evaluator & ToString {
    public open override func matches(root: Element, element: Element): Bool {
        let p: ?Element = element.parent()
        return ((p.isSome()) && !(p is Document)) && element.siblingElements().isEmpty()
    }
    public open override func toString(): String {
        return ":only-child"
    }
}

class IsOnlyOfType <: Evaluator & ToString {
    public open override func matches(root: Element, element: Element): Bool {
        let p: ?Element = element.parent()
        if ((p.isNone()) || (p is Document)) {
            return false
        }
        var pos = 0
        var next: ?Element = p.getOrThrow().firstElementChild()
        while (next.isSome()) {
            if (next.getOrThrow().normalName() == element.normalName()) {
                pos += 1
            }
            if (pos > 1) {
                break
            }
            next = next.getOrThrow().nextElementSibling()
        }
        return pos == 1
    }
    public open override func toString(): String {
        return ":only-of-type"
    }
}

class IsEmpty <: Evaluator & ToString {
    public open override func matches(root: Element, element: Element): Bool {
        var n = element.firstChild()
        while (n.isSome()) {
            if ((n is TextNode)) {
                if (!n.isBlank()) {
                    return false
                }
            } else if (!(((n is Comment) || (n is XmlDeclaration)) || (n is DocumentType))) {
                return false
            }
            n = n.nextSibling()
        }
        return true
    }
    public open override func toString(): String {
        return ":empty"
    }
}

abstract class IndexEvaluator <: Evaluator {
    var index: Int64
    init(index: Int64) {
        this.index = index
    }
}

class ContainsText <: Evaluator & ToString {
    init(searchText: String) {
        this.searchText = lowerCase(normaliseWhitespace(searchText))
    }
    let searchText: String
    public open override func matches(root: Element, element: Element): Bool {
        return lowerCase(element.text()).contains(searchText)
    }
    public open override func cost(): Int64 {
        return 10
    }
    public open override func toString(): String {
        return ":contains(${searchText})"
    }
}

class ContainsWholeText <: Evaluator & ToString {
    let searchText: String
    init(searchText: String) {
        this.searchText = searchText
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.wholeText().contains(searchText)
    }
    public open override func cost(): Int64 {
        return 10
    }
    public open override func toString(): String {
        return ":containsWholeText(${searchText})"
    }
}

class ContainsWholeOwnText <: Evaluator & ToString {
    let searchText: String
    init(searchText: String) {
        this.searchText = searchText
    }
    public open override func matches(root: Element, element: Element): Bool {
        return element.wholeOwnText().contains(searchText)
    }
    public open override func toString(): String {
        return ":containsWholeOwnText(${searchText})"
    }
}

class ContainsData <: Evaluator & ToString {
    init(searchText: ?String) {
        this.searchText = lowerCase(searchText)
    }
    let searchText: String
    public open override func matches(root: Element, element: Element): Bool {
        return lowerCase(element.data()).contains(searchText)
    }
    public open override func toString(): String {
        return ":containsData(${searchText})"
    }
}

class ContainsOwnText <: Evaluator & ToString {
    init(searchText: String) {
        this.searchText = lowerCase(normaliseWhitespace(searchText))
    }
    let searchText: String
    public open override func matches(root: Element, element: Element): Bool {
        return lowerCase(element.ownText()).contains(searchText)
    }
    public open override func toString(): String {
        return ":containsOwn(${searchText})"
    }
}

class Matches <: Evaluator & ToString {
    let pattern: Regex
    init(pattern: Regex) {
        this.pattern = pattern
    }
    public open override func matches(root: Element, element: Element): Bool {
        return pattern.containsMatchIn(element.text())
    }
    public open override func cost(): Int64 {
        return 8
    }
    public open override func toString(): String {
        return ":matches(${pattern.pattern})"
    }
}

class MatchesOwn <: Evaluator & ToString {
    let pattern: Regex
    init(pattern: Regex) {
        this.pattern = pattern
    }
    public open override func matches(root: Element, element: Element): Bool {
        return pattern.containsMatchIn(element.ownText())
    }
    public open override func cost(): Int64 {
        return 7
    }
    public open override func toString(): String {
        return ":matchesOwn(${pattern.pattern})"
    }
}

class MatchesWholeText <: Evaluator & ToString {
    let pattern: Regex
    init(pattern: Regex) {
        this.pattern = pattern
    }
    public open override func matches(root: Element, element: Element): Bool {
        return pattern.containsMatchIn(element.wholeText())
    }
    public open override func cost(): Int64 {
        return 8
    }
    public open override func toString(): String {
        return ":matchesWholeText(${pattern.pattern})"
    }
}

class MatchesWholeOwnText <: Evaluator & ToString {
    let pattern: Regex
    init(pattern: Regex) {
        this.pattern = pattern
    }
    public open override func matches(root: Element, element: Element): Bool {
        return pattern.containsMatchIn(element.wholeOwnText())
    }
    public open override func cost(): Int64 {
        return 7
    }
    public open override func toString(): String {
        return ":matchesWholeOwnText(${pattern.pattern})"
    }
}

class MatchText <: Evaluator & ToString {
    init() {
        if (!MatchText.loggedError) {
            MatchText.loggedError = true
            println("WARNING: :matchText selector is deprecated and will be removed in a future version. Use Element#selectNodes(String, Class) with selector ::textnode and class TextNode instead.")
        }
    }
    static var loggedError: Bool = false
    public open override func matches(root: Element, element: Element): Bool {
        if ((element is PseudoTextElement)) {
            return true
        }
        let textNodes: ArrayList<TextNode> = element.textNodes()
        for (textNode in textNodes) {
            let pel = PseudoTextElement(com.fleeksoft.ksoup.parser.Tag.valueOf(element.tagName(), element.tag().namespace(), ParseSettings.preserveCase), element.baseUri(), element.attributes())
            textNode.replaceWith(pel)
            pel.appendChild(textNode)
        }
        return false
    }
    public open override func cost(): Int64 {
        return -1
    }
    public open override func toString(): String {
        return ":matchText"
    }
}

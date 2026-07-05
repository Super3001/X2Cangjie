package target_1g

open class Printer <: NodeVisitor {
    let root: Node
    let accum: QuietAppendable
    let settings: Document.OutputSettings
    init(root: Node, accum: QuietAppendable, settings: Document.OutputSettings) {
        this.root = root
        this.accum = accum
        this.settings = settings
    }
    public open func addHead(el: Element, depth: Int64) {
        el.outerHtmlHead(accum, settings)
    }
    public open func addTail(el: Element, depth: Int64) {
        el.outerHtmlTail(accum, settings)
    }
    public open func addText(textNode: TextNode, textOptions: Int64, depth: Int64) {
        let options = Entities.ForText | textOptions
        Entities.escape(accum, textNode.coreValue(), settings, options)
    }
    public open func addNode(node: LeafNode, depth: Int64) {
        node.outerHtmlHead(accum, settings)
    }
    public open func indent(depth: Int64) {
        accum.append(r'\n').append(StringUtil.padding(depth * settings.indentAmount(), settings.maxPaddingWidth()))
    }
    public open override func head(node: Node, depth: Int64) {
        if (node == TextNode) {
            addText((node as TextNode), 0, depth)
        } else if ((node is Element)) {
            addHead(node, depth)
        } else {
            addNode((node as LeafNode), depth)
        }
    }
    public open override func tail(node: Node, depth: Int64) {
        if ((node is Element)) {
            addTail(node, depth)
        }
    }
    public static func printerFor(root: Node, accum: QuietAppendable): Printer {
        let settings = NodeUtils.outputSettings(root)
        return if (settings.outline()) {
            Outline(root, accum, settings)
        } else if (settings.prettyPrint()) {
            Pretty(root, accum, settings)
        } else {
            Printer(root, accum, settings)
        }
    }
}

open class Pretty <: Printer {
    init(root: Node, accum: QuietAppendable, settings: Document.OutputSettings) {
        super(root, accum, settings)
        var node: ?Node = root
        while (node.isSome()) {
            if (tagIs(Tag.PreserveWhitespace, node)) {
                preserveWhitespace = true
                break
            }
            node = node.getOrThrow().parentNode()
        }
    }
    var preserveWhitespace: Bool = false
    public open override func addHead(el: Element, depth: Int64) {
        if (shouldIndent(el)) {
            indent(depth)
        }
        super.addHead(el, depth)
        if (tagIs(Tag.PreserveWhitespace, el)) {
            preserveWhitespace = true
        }
    }
    public open override func addTail(el: Element, depth: Int64) {
        if (shouldIndent(nextNonBlank(el.firstChild()))) {
            indent(depth)
        }
        super.addTail(el, depth)
        if (preserveWhitespace && el.tag.`is`(Tag.PreserveWhitespace)) {
            var parent = el.parent()
            while (parent.isSome()) {
                if (parent.tag().preserveWhitespace()) {
                    return
                }
                parent = parent.parent()
            }
            preserveWhitespace = false
        }
    }
    public open override func addNode(node: LeafNode, depth: Int64) {
        if (shouldIndent(node)) {
            indent(depth)
        }
        super.addNode(node, depth)
    }
    public open override func addText(node: TextNode, textOptions: Int64, depth: Int64) {
        var options = textOptions
        if (!preserveWhitespace) {
            options = options | Entities.Normalise
            options = textTrim(node, options)
            if ((!node.isBlank() && isBlockEl(node.parentNode())) && shouldIndent(node)) {
                indent(depth)
            }
        }
        super.addText(node, options, depth)
    }
    public open func textTrim(node: TextNode, options: Int64): Int64 {
        if (!isBlockEl(node.parentNode())) {
            return options
        }
        let prev = node.previousSibling()
        var next = node.nextSibling()
        var opts = options
        if (!(prev is Element) || isBlockEl(prev)) {
            if ((prev.isNone()) || (!(prev is TextNode) && shouldIndent(prev))) {
                opts = opts | Entities.TrimLeading
            }
        }
        if ((next.isNone()) || (!(next is TextNode) && shouldIndent(next))) {
            opts = opts | Entities.TrimTrailing
        } else {
            next = Pretty.nextNonBlank(next)
            if ((next is TextNode) && StringUtil.isAsciiWhiteSpace(next.nodeValue().codePointAt(0).value)) {
                opts = opts | Entities.TrimTrailing
            }
        }
        return opts
    }
    public open func shouldIndent(node: ?Node): Bool {
        if ((((node.isNone()) || (node == root)) || preserveWhitespace) || isBlankText(node)) {
            return false
        }
        if (isBlockEl(node)) {
            return true
        }
        let prevSib = previousNonblank(node)
        if (isBlockEl(prevSib)) {
            return true
        }
        let parent = node.getOrThrow()._parentNode
        if ((!isBlockEl(parent) || parent.tag().`is`(Tag.InlineContainer)) || !hasNonTextNodes(parent)) {
            return false
        }
        return (prevSib.isNone()) || (!(prevSib is TextNode) && (isBlockEl(prevSib) || !(prevSib is Element)))
    }
    public open func isBlockEl(node: ?Node): Bool {
        if (node.isNone()) {
            return false
        }
        if ((node is Element)) {
            let el = node
            if (el.getOrThrow().nameIs("br")) {
                return true
            }
            return el.getOrThrow().isBlock() || (!el.getOrThrow().tag.isKnownTag() && ((el.getOrThrow().parentNode() is Document) || hasChildBlocks(el)))
        }
        return false
    }
    static let maxScan = 5
    public static func hasChildBlocks(el: Element): Bool {
        var child = el.firstElementChild()
        var i = 0
        while ((i < Pretty.maxScan) && (child.isSome())) {
            if (child.isBlock() || !child.tag.isKnownTag()) {
                return true
            }
            child = child.nextElementSibling()
            i += 1
        }
        return false
    }
    public static func hasNonTextNodes(el: Element): Bool {
        var child = el.firstChild()
        var i = 0
        while ((i < Pretty.maxScan) && (child.isSome())) {
            if (!(child is TextNode)) {
                return true
            }
            child = child.nextSibling()
            i += 1
        }
        return false
    }
    public static func previousNonblank(node: Node): ?Node {
        var prev = node.previousSibling()
        while (isBlankText(prev)) {
            prev = prev?.previousSibling()
        }
        return prev
    }
    public static func nextNonBlank(node: ?Node): ?Node {
        var n = node
        while (isBlankText(n)) {
            n = n?.nextSibling()
        }
        return n
    }
    public static func isBlankText(node: ?Node): Bool {
        return (node is TextNode) && node.getOrThrow().isBlank()
    }
    public static func tagIs(option: Int64, node: ?Node): Bool {
        return (node is Element) && node.getOrThrow().tag.`is`(option)
    }
}

open class Outline <: Pretty {
    init(root: Node, accum: QuietAppendable, settings: Document.OutputSettings) {
        super(root, accum, settings)
    }
    public open override func isBlockEl(node: ?Node): Bool {
        return node.isSome()
    }
    public open override func shouldIndent(node: ?Node): Bool {
        if ((((node.isNone()) || (node == root)) || preserveWhitespace) || isBlankText(node)) {
            return false
        }
        if ((node is TextNode)) {
            return (node.getOrThrow().previousSibling().isSome()) || (node.getOrThrow().nextSibling().isSome())
        }
        return true
    }
}

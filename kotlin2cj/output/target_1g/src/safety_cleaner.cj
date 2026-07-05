package target_1g

import std.collection.*

class Cleaner {
    let safelist: Safelist
    init(safelist: Safelist) {
        this.safelist = safelist
    }
    func clean(dirtyDocument: Document): Document {
        let clean: Document = Document.createShell(dirtyDocument.baseUri())
        copySafeNodes(dirtyDocument.body(), clean.body())
        clean.outputSettings(dirtyDocument.outputSettings().clone())
        return clean
    }
    func isValid(dirtyDocument: Document): Bool {
        let clean: Document = Document.createShell(dirtyDocument.baseUri())
        let numDiscarded = copySafeNodes(dirtyDocument.body(), clean.body())
        return (numDiscarded == 0) && dirtyDocument.head().childNodes().isEmpty()
    }
    func isValidBodyHtml(bodyHtml: String): Bool {
        let baseUri: ?String = if (safelist.preserveRelativeLinks()) {
            SharedConstants.DummyUri
        } else {
            ""
        }
        let clean = Document.createShell(baseUri.getOrThrow())
        let dirty = Document.createShell(baseUri)
        let errorList = ParseErrorList.tracking(1)
        let nodes: ArrayList<Node> = Parser.parseFragment(bodyHtml, dirty.body(), baseUri, errorList)
        dirty.body().insertChildren(0, nodes)
        let numDiscarded = copySafeNodes(dirty.body(), clean.body())
        return (numDiscarded == 0) && errorList.isEmpty()
    }
    func copySafeNodes(source: Element, dest: Element): Int64 {
        let cleaningVisitor = CleaningVisitor(source, dest)
        cleaningVisitor.traverse(source)
        return cleaningVisitor.numDiscarded
    }
    func createSafeElement(sourceEl: Element): ElementMeta {
        let dest = sourceEl.shallowClone()
        let sourceTag = sourceEl.tagName()
        let destAttrs = dest.attributes()
        dest.clearAttributes()
        var numDiscarded = 0
        let sourceAttrs = sourceEl.attributes()
        for (sourceAttr in sourceAttrs) {
            if (safelist.isSafeAttribute(sourceTag, sourceEl, sourceAttr)) {
                destAttrs.put(sourceAttr)
            } else {
                numDiscarded += 1
            }
        }
        let enforcedAttrs = safelist.getEnforcedAttributes(sourceTag)
        if (sourceEl.nameIs("a") && (enforcedAttrs["rel"] == "nofollow")) {
            let href = sourceEl.absUrl("href")
            let sourceBase = sourceEl.baseUri()
            if ((!href.isEmpty() && !sourceBase.isEmpty()) && href.startsWith(sourceBase)) {
                enforcedAttrs.remove("rel")
            }
        }
        destAttrs.add(all: enforcedAttrs)
        dest.attributes().add(all: destAttrs)
        return ElementMeta(dest, numDiscarded)
    }
}

class CleaningVisitor <: NodeVisitor {
    let root: Element
    var destination: Element
    init(root: Element, destination: Element) {
        this.root = root
        this.destination = destination
    }
    var numDiscarded = 0
    public override func head(node: Node, depth: Int64) {
        if ((node is Element)) {
            if (safelist.isSafeTag(node.normalName())) {
                let meta: ElementMeta = createSafeElement(node)
                let destChild: Element = meta.el
                destination.appendChild(destChild)
                numDiscarded += meta.numAttribsDiscarded
                destination = destChild
            } else if (node != root) {
                numDiscarded += 1
            }
        } else if ((node is TextNode)) {
            let destText = TextNode(node.getWholeText())
            destination.appendChild(destText)
        } else if ((node is DataNode) && safelist.isSafeTag(node.parent().getOrThrow().normalName())) {
            let sourceData = node
            let destData = DataNode(sourceData.getWholeData())
            destination.appendChild(destData)
        } else {
            numDiscarded += 1
        }
    }
    public override func tail(node: Node, depth: Int64) {
        if ((node is Element) && safelist.isSafeTag(node.normalName())) {
            destination = destination.parent().getOrThrow()
        }
    }
}

class ElementMeta {
    var el: Element
    var numAttribsDiscarded: Int64
    init(el: Element, numAttribsDiscarded: Int64) {
        this.el = el
        this.numAttribsDiscarded = numAttribsDiscarded
    }
}

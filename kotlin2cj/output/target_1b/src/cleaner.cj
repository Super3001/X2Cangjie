package target_1b

import std.collection.*

class Cleaner {
    let safelist: Safelist
    init(safelist: Safelist) {
        this.safelist = safelist
    }
    func clean(dirtyDocument: Document): Document {
        let clean: Document = Document.createShell(dirtyDocument.baseUri())
        copySafeNodes(dirtyDocument.body(), clean.body())
        let settings = dirtyDocument.outputSettings()
        if (let Some(s) <- settings) { clean.outputSettings(s) }
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
        let dirty = Document.createShell(baseUri.getOrThrow())
        let errorList = ParseErrorList.tracking(1)
        let nodes: ArrayList<Node> = Parser.parseFragment(bodyHtml, dirty.body(), baseUri.getOrThrow(), errorList)
        dirty.body().insertChildren(0, nodes)
        let numDiscarded = copySafeNodes(dirty.body(), clean.body())
        return (numDiscarded == 0) && errorList.isEmpty()
    }
    func copySafeNodes(source: Element, dest: Element): Int64 {
        let cleaningVisitor = CleaningVisitor(this, source, dest)
        let traversor = NodeTraversor(cleaningVisitor)
        traversor.traverse(source)
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
        if (sourceEl.nameIs("a") && (enforcedAttrs.get("rel").getOrThrow() == "nofollow")) {
            let href = sourceEl.absUrl("href")
            let sourceBase = sourceEl.baseUri()
            if ((!href.isEmpty() && !sourceBase.isEmpty()) && href.startsWith(sourceBase)) {
                enforcedAttrs.remove("rel")
            }
        }
        // copy enforced attrs to destAttrs via iterator
        let iter = enforcedAttrs.iterator()
        while (let Some(attr) <- iter.next()) {
            destAttrs.put(attr)
        }
        return ElementMeta(dest, numDiscarded)
    }
}

class CleaningVisitor <: NodeVisitor {
    let cleaner: Cleaner
    let root: Element
    var destination: Element
    init(cleaner: Cleaner, root: Element, destination: Element) {
        this.cleaner = cleaner
        this.root = root
        this.destination = destination
    }
    var numDiscarded = 0
    public override func head(node: Node, depth: Int64) {
        if ((node is Element)) {
            let el = (node as Element)
            if (let Some(elem) <- el) {
                if (cleaner.safelist.isSafeTag(elem.normalName())) {
                    let meta: ElementMeta = cleaner.createSafeElement(elem)
                    let destChild: Element = meta.el
                    destination.appendChild(destChild)
                    numDiscarded += meta.numAttribsDiscarded
                    destination = destChild
                } else {
                    numDiscarded += 1
                }
            }
        } else if ((node is TextNode)) {
            let tn = (node as TextNode)
            if (let Some(text) <- tn) {
                let destText = TextNode(text.getWholeText())
                destination.appendChild(destText)
            }
        } else if ((node is DataNode)) {
            let dn = (node as DataNode)
            if (let Some(data) <- dn) {
                if (cleaner.safelist.isSafeTag(data.parent().getOrThrow().normalName())) {
                    let destData = DataNode(data.getWholeData())
                    destination.appendChild(destData)
                }
            }
        } else {
            numDiscarded += 1
        }
    }
    public override func tail(node: Node, depth: Int64) {
        if ((node is Element)) {
            let el = (node as Element)
            if (let Some(elem) <- el) {
                if (cleaner.safelist.isSafeTag(elem.normalName())) {
                    destination = elem.parent().getOrThrow()
                }
            }
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

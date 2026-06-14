package ksoup_cj

import std.collection.*

class TagSet {
    let tags: HashMap<String, HashMap<String, Tag>> = HashMap()
    let source: ?TagSet
    var customizers: ?ArrayList<(Tag) -> Unit> = None
    init(original: ?TagSet, customizers!: ?ArrayList<(Tag) -> Unit> = None) {
        this.source = original
        this.customizers = customizers
    }
    init() {
        this(None, None)
    }
    init(template: TagSet) {
        this(template.source, copyCustomizers(template))
        if (template.tags.isEmpty()) {
            return
        }
        for (namespaceEntry in template.tags.entries) {
            let nsTags: HashMap<String, Tag> = HashMap([namespaceEntry.value.size])
            for (tagEntry in namespaceEntry.value.entries) {
                nsTags[tagEntry.key] = tagEntry.value.clone()
            }
            tags[namespaceEntry.key] = nsTags
        }
    }
    func add(tag: Tag): TagSet {
        tag.set(Tag.Known)
        doAdd(tag)
        return this
    }
    func doAdd(tag: Tag) {
        if (let Some(customizersValue) <- customizers) {
            let customizers = customizersValue
            for (customizer in customizers) {
                customizer(tag)
            }
        }
        let ns = tag.namespace()
        if (!tags.contains(ns)) {
            tags[ns] = HashMap()
        }
        tags[ns][tag.tagName] = tag
    }
    func get(tagName: String, namespace: String): ?Tag {
        if (let Some(nsTags) <- tags.get(namespace)) {
            if (let Some(it) <- nsTags.get(tagName)) {
                return it
            }
        }
        if (let Some(tag) <- source?.get(tagName, namespace)) {
            let copy = tag.clone()
            doAdd(copy)
            return copy
        }
        return None
    }
    func valueOf(tagName: String, normalNameParam: ?String, namespace: String, preserveTagCase: Bool): Tag {
        var tName = tagName.trimAscii()
        Validate.notEmpty(tName)
        var tag = get(tName, namespace)
        if (let Some(tagValue) <- tag) {
            let tag = tagValue
            return tag
        }
        var normalName = normalNameParam
        if (normalName.isNone()) {
            normalName = ParseSettings.normalName(tagName)
        }
        tName = if (preserveTagCase) {
            tName
        } else {
            normalName
        }
        tag = get(normalName, namespace)
        if (tag.isSome()) {
            if (preserveTagCase && (tName != normalName)) {
                tag = tag.clone()
                tag.tagName = tName
                doAdd(tag)
            }
            return tag
        }
        tag = Tag(tName, normalName, namespace)
        doAdd(tag)
        return tag
    }
    func valueOf(tagName: String, namespace: String, settings!: ParseSettings = ParseSettings.preserveCase): Tag {
        return valueOf(tagName, None, namespace, settings.preserveTagCase())
    }
    func onNewTag(customizer: (Tag) -> Unit): TagSet {
        if (customizers.isNone()) {
            customizers = ArrayList()
        }
        customizers?.add(customizer)
        return this
    }
    public override func equals(other: ?Object): Bool {
        if (!(other is TagSet)) {
            return false
        }
        return tags == other.getOrThrow().tags
    }
    public override func hashCode(): Int64 {
        return tags.hashCode()
    }
    func setupTags(namespace: String, tagNames: Array<String>, tagModifier: (Tag) -> Unit): TagSet {
        for (tagName in tagNames) {
            var tag = get(tagName, namespace)
            if (tag.isNone()) {
                tag = Tag(tagName, tagName, namespace)
                tag.options = 0
                add(tag)
            }
            tagModifier(tag)
        }
        return this
    }
    static func HtmlTagSet(): TagSet {
        return { => initHtmlDefault() }()
    }
    static func Html(): TagSet {
        return TagSet(TagSet.HtmlTagSet(), None)
    }
    static func copyCustomizers(base: TagSet): ?ArrayList<(Tag) -> Unit> {
        if (base.customizers.isNone()) {
            return None
        }
        return ArrayList([base.customizers.getOrThrow()])
    }
    static func initHtmlDefault(): TagSet {
        let blockTags = ["html", "head", "body", "frameset", "script", "noscript", "style", "meta", "link", "title", "frame", "noframes", "section", "nav", "aside", "hgroup", "header", "footer", "p", "h1", "h2", "h3", "h4", "h5", "h6", "button", "ul", "ol", "pre", "div", "blockquote", "hr", "address", "figure", "figcaption", "form", "fieldset", "ins", "del", "dl", "dt", "dd", "li", "table", "caption", "thead", "tfoot", "tbody", "colgroup", "col", "tr", "th", "td", "video", "audio", "canvas", "details", "menu", "plaintext", "template", "article", "main", "center", "template", "dir", "applet", "marquee", "listing", "#root"]
        let inlineTags = ["object", "base", "font", "tt", "i", "b", "u", "big", "small", "em", "strong", "dfn", "code", "samp", "kbd", "var", "cite", "abbr", "time", "acronym", "mark", "ruby", "rt", "rp", "rtc", "a", "img", "wbr", "map", "q", "sub", "sup", "bdo", "iframe", "embed", "span", "input", "select", "textarea", "label", "optgroup", "option", "legend", "datalist", "keygen", "output", "progress", "meter", "area", "param", "source", "track", "summary", "command", "device", "area", "basefont", "bgsound", "menuitem", "param", "source", "track", "data", "bdi", "s", "strike", "nobr", "rb"]
        let inlineContainers = ["title", "a", "p", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "address", "li", "th", "td", "script", "style", "ins", "del", "s", "button"]
        let voidTags = ["meta", "link", "base", "frame", "img", "br", "wbr", "embed", "hr", "input", "keygen", "col", "command", "device", "area", "basefont", "bgsound", "menuitem", "param", "source", "track"]
        let preserveWhitespaceTags = ["pre", "plaintext", "title", "textarea", "script"]
        let rcdataTags = ["title", "textarea"]
        let dataTags = ["iframe", "noembed", "noframes", "script", "style", "xmp"]
        let formSubmitTags: Array<String> = SharedConstants.FormSubmitTags
        let blockMathTags = ["math"]
        let inlineMathTags = ["mi", "mo", "msup", "mn", "mtext"]
        let blockSvgTags = ["svg", "femerge", "femergenode"]
        let inlineSvgTags = ["text"]
        let dataSvgTags = ["script"]
        return TagSet().setupTags(Parser.NamespaceHtml, blockTags, { it => it.set(Tag.Block) }).setupTags(Parser.NamespaceHtml, inlineTags, { it => it.set(0) }).setupTags(Parser.NamespaceHtml, inlineContainers, { it => it.set(Tag.InlineContainer) }).setupTags(Parser.NamespaceHtml, voidTags, { it => it.set(Tag.Void) }).setupTags(Parser.NamespaceHtml, preserveWhitespaceTags, { it => it.set(Tag.PreserveWhitespace) }).setupTags(Parser.NamespaceHtml, rcdataTags, { it => it.set(Tag.RcData) }).setupTags(Parser.NamespaceHtml, dataTags, { it => it.set(Tag.Data) }).setupTags(Parser.NamespaceHtml, formSubmitTags, { it => it.set(Tag.FormSubmittable) }).setupTags(Parser.NamespaceMathml, blockMathTags, { it => it.set(Tag.Block) }).setupTags(Parser.NamespaceMathml, inlineMathTags, { it => it.set(0) }).setupTags(Parser.NamespaceSvg, blockSvgTags, { it => it.set(Tag.Block) }).setupTags(Parser.NamespaceSvg, inlineSvgTags, { it => it.set(0) }).setupTags(Parser.NamespaceSvg, dataSvgTags, { it => it.set(Tag.Data) })
    }
}

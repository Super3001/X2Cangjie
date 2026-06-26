package target_1b

import std.collection.*

open class Safelist {
    init() {}
    let tagNames: HashSet<TagName> = HashSet()
    let attributes: HashMap<TagName, HashSet<AttributeKey>> = HashMap()
    let enforcedAttributes: HashMap<TagName, HashMap<AttributeKey, AttributeValue>> = HashMap()
    let protocols: HashMap<TagName, HashMap<AttributeKey, HashSet<Protocol>>> = HashMap()
    var _preserveRelativeLinks = false
    init(copy: Safelist) {
        this()
        tagNames.add(all: copy.tagNames)
        for ((key, value) in copy.attributes) {
            let s = HashSet<AttributeKey>()
            s.add(all: value)
            attributes[key] = s
        }
        for ((key, value) in copy.enforcedAttributes) {
            let m = HashMap<AttributeKey, AttributeValue>()
            for ((k, v) in value) { m[k] = v }
            enforcedAttributes[key] = m
        }
        for ((key, value) in copy.protocols) {
            let attributeProtocolsCopy: HashMap<AttributeKey, HashSet<Protocol>> = HashMap()
            for ((key1, value1) in value) {
                let s = HashSet<Protocol>()
                s.add(all: value1)
                attributeProtocolsCopy[key1] = s
            }
            protocols[key] = attributeProtocolsCopy
        }
        _preserveRelativeLinks = copy.preserveRelativeLinks()
    }
    public open func addTags(tags: Array<String>): Safelist {
        for (tagName in tags) {
            Validate.notEmpty(tagName)
            Validate.isFalse((tagName.toAsciiLower() == "noscript".toAsciiLower()), "noscript is unsupported in Safelists, due to incompatibilities between parsers with and without script-mode enabled")
            tagNames.add(TagName.valueOf(tagName))
        }
        return this
    }
    public open func removeTags(tags: Array<String>): Safelist {
        for (tag in tags) {
            Validate.notEmpty(tag)
            let tagName = TagName.valueOf(tag)
            if (tagNames.remove(tagName)) {
                attributes.remove(tagName)
                enforcedAttributes.remove(tagName)
                protocols.remove(tagName)
            }
        }
        return this
    }
    public open func addAttributes(tag: String, attributes: Array<String>): Safelist {
        Validate.notEmpty(tag)
        Validate.isTrue(!(attributes.isEmpty()), "No attribute names supplied.")
        addTags([tag])
        let tagName: TagName = TagName.valueOf(tag)
        let attributeSet: HashSet<AttributeKey> = HashSet()
        for (key in attributes) {
            Validate.notEmpty(key)
            attributeSet.add(AttributeKey.valueOf(key))
        }
        let attr = if (this.attributes.contains(tagName)) { this.attributes[tagName] } else { let _v = HashSet<AttributeKey>(); this.attributes[tagName] = _v; _v }
        attr.add(all: attributeSet)
        return this
    }
    public open func removeAttributes(tag: String, attributes: Array<String>): Safelist {
        Validate.notEmpty(tag)
        Validate.isTrue(!(attributes.isEmpty()), "No attribute names supplied.")
        let tagName = TagName.valueOf(tag)
        let attributeSet: HashSet<AttributeKey> = HashSet()
        for (key in attributes) {
            Validate.notEmpty(key)
            attributeSet.add(AttributeKey.valueOf(key))
        }
        if (tagNames.contains(tagName) && this.attributes.contains(tagName)) {
            let currentSet: HashSet<AttributeKey> = this.attributes[tagName]
            for (attr in attributeSet) { currentSet.remove(attr) }
            if (currentSet.isEmpty()) {
                this.attributes.remove(tagName)
            }
        }
        if (tag == Safelist.All) {
            for ((key, currentSet) in this.attributes) {
                for (attr in attributeSet) { currentSet.remove(attr) }
                if (currentSet.isEmpty()) {
                    this.attributes.remove(key)
                }
            }
        }
        return this
    }
    public open func addEnforcedAttribute(tag: String, attribute: String, value: String): Safelist {
        Validate.notEmpty(tag)
        Validate.notEmpty(attribute)
        Validate.notEmpty(value)
        let tagName = TagName.valueOf(tag)
        tagNames.add(tagName)
        let attrKey = AttributeKey.valueOf(attribute)
        let attrVal = AttributeValue.valueOf(value)
        if (enforcedAttributes.contains(tagName)) {
            if (let Some(m) <- enforcedAttributes.get(tagName)) { m[attrKey] = attrVal }
        } else {
            let attrMap: HashMap<AttributeKey, AttributeValue> = HashMap()
            attrMap[attrKey] = attrVal
            enforcedAttributes[tagName] = attrMap
        }
        return this
    }
    public open func removeEnforcedAttribute(tag: String, attribute: String): Safelist {
        Validate.notEmpty(tag)
        Validate.notEmpty(attribute)
        let tagName = TagName.valueOf(tag)
        if (tagNames.contains(tagName) && enforcedAttributes.contains(tagName)) {
            let attrKey = AttributeKey.valueOf(attribute)
            let attrMap: ?HashMap<AttributeKey, AttributeValue> = enforcedAttributes[tagName]
            attrMap?.remove(attrKey)
            if (attrMap?.isEmpty() == true) {
                enforcedAttributes.remove(tagName)
            }
        }
        return this
    }
    public open func preserveRelativeLinks(preserve: Bool): Safelist {
        _preserveRelativeLinks = preserve
        return this
    }
    public open func preserveRelativeLinks(): Bool {
        return _preserveRelativeLinks
    }
    public open func addProtocols(tag: String, attribute: String, protocols: Array<String>): Safelist {
        Validate.notEmpty(tag)
        Validate.notEmpty(attribute)
        let tagName = TagName.valueOf(tag)
        let attrKey = AttributeKey.valueOf(attribute)
        let attrMap = if (this.protocols.contains(tagName)) { this.protocols[tagName] } else { let _v = HashMap<AttributeKey, HashSet<Protocol>>(); this.protocols[tagName] = _v; _v }
        let protSet = if (attrMap.contains(attrKey)) { attrMap[attrKey] } else { let _v = HashSet<Protocol>(); attrMap[attrKey] = _v; _v }
        for (protocol in protocols) {
            Validate.notEmpty(protocol)
            let prot = Protocol.valueOf(protocol)
            protSet.add(prot)
        }
        return this
    }
    public open func removeProtocols(tag: String, attribute: String, removeProtocols: Array<String>): Safelist {
        Validate.notEmpty(tag)
        Validate.notEmpty(attribute)
        let tagName = TagName.valueOf(tag)
        let attr = AttributeKey.valueOf(attribute)
        Validate.isTrue(protocols.contains(tagName), "Cannot remove a protocol that is not set.")
        let tagProtocols: HashMap<AttributeKey, HashSet<Protocol>> = protocols[tagName]
        Validate.isTrue(tagProtocols.contains(attr), "Cannot remove a protocol that is not set.")
        let attrProtocols: HashSet<Protocol> = tagProtocols[attr]
        for (protocol in removeProtocols) {
            Validate.notEmpty(protocol)
            attrProtocols.remove(Protocol.valueOf(protocol))
        }
        if (attrProtocols.isEmpty()) {
            tagProtocols.remove(attr)
            if (tagProtocols.isEmpty()) {
                protocols.remove(tagName)
            }
        }
        return this
    }
    public open func isSafeTag(tag: String): Bool {
        return tagNames.contains(TagName.valueOf(tag))
    }
    public open func isSafeAttribute(tagName: String, el: Element, attr: Attribute): Bool {
        let tag = TagName.valueOf(tagName)
        let key = AttributeKey.valueOf(attr.key)
        let okSet: ?HashSet<AttributeKey> = attributes[tag]
        if ((okSet.isSome()) && okSet.getOrThrow().contains(key)) {
            return if (protocols.contains(tag)) {
                let attrProts: HashMap<AttributeKey, HashSet<Protocol>> = protocols[tag]
                !attrProts.contains(key) || testValidProtocol(el, attr, attrProts[key])
            } else {
                true
            }
        }
        let enforcedSet: ?HashMap<AttributeKey, AttributeValue> = enforcedAttributes[tag]
        if (let Some(enforcedSetValue) <- enforcedSet) {
            let enforcedSet = enforcedSetValue
            let expect: Attributes = getEnforcedAttributes(tagName)
            let attrKey: String = attr.key
            if (expect.hasKeyIgnoreCase(attrKey)) {
                return (expect.getIgnoreCase(attrKey) == attr.value)
            }
        }
        return (tagName != Safelist.All) && isSafeAttribute(Safelist.All, el, attr)
    }
    public open func testValidProtocol(el: Element, attr: Attribute, protocols: HashSet<Protocol>): Bool {
        var value: String = el.absUrl(attr.key)
        if (value.isEmpty()) {
            value = attr.value
        }
        if (!_preserveRelativeLinks) {
            attr.setValue(value)
        }
        for (protocol in protocols) {
            var prot = protocol.toString()
            if (prot == "#") {
                return if (isValidAnchor(value)) {
                    true
                } else {
                    continue
                }
            }
            prot += ":"
            if (value.toAsciiLower().startsWith(prot)) {
                return true
            }
        }
        return false
    }
    public open func getEnforcedAttributes(tagName: String): Attributes {
        let attrs = Attributes()
        let tag = TagName.valueOf(tagName)
        if (enforcedAttributes.contains(tag)) {
            let keyVals: HashMap<AttributeKey, AttributeValue> = enforcedAttributes[tag]
            for ((key, value) in keyVals) {
                attrs.put(key.toString(), value.toString())
            }
        }
        return attrs
    }
    static let All = ":all"
    public static func none(): Safelist {
        return Safelist()
    }
    public static func simpleText(): Safelist {
        return Safelist().addTags(["b", "em", "i", "strong", "u"])
    }
    public static func basic(): Safelist {
        return Safelist().addTags(["a", "b", "blockquote", "br", "cite", "code", "dd", "dl", "dt", "em", "i", "li", "ol", "p", "pre", "q", "small", "span", "strike", "strong", "sub", "sup", "u", "ul"]).addAttributes("a", ["href"]).addAttributes("blockquote", ["cite"]).addAttributes("q", ["cite"]).addProtocols("a", "href", ["ftp", "http", "https", "mailto"]).addProtocols("blockquote", "cite", ["http", "https"]).addProtocols("cite", "cite", ["http", "https"]).addEnforcedAttribute("a", "rel", "nofollow")
    }
    public static func basicWithImages(): Safelist {
        return basic().addTags(["img"]).addAttributes("img", ["align", "alt", "height", "src", "title", "width"]).addProtocols("img", "src", ["http", "https"])
    }
    public static func relaxed(): Safelist {
        return Safelist().addTags(["a", "b", "blockquote", "br", "caption", "cite", "code", "col", "colgroup", "dd", "div", "dl", "dt", "em", "h1", "h2", "h3", "h4", "h5", "h6", "i", "img", "li", "ol", "p", "pre", "q", "small", "span", "strike", "strong", "sub", "sup", "table", "tbody", "td", "tfoot", "th", "thead", "tr", "u", "ul"]).addAttributes("a", ["href", "title"]).addAttributes("blockquote", ["cite"]).addAttributes("col", ["span", "width"]).addAttributes("colgroup", ["span", "width"]).addAttributes("img", ["align", "alt", "height", "src", "title", "width"]).addAttributes("ol", ["start", "type"]).addAttributes("q", ["cite"]).addAttributes("table", ["summary", "width"]).addAttributes("td", ["abbr", "axis", "colspan", "rowspan", "width"]).addAttributes("th", ["abbr", "axis", "colspan", "rowspan", "scope", "width"]).addAttributes("ul", ["type"]).addProtocols("a", "href", ["ftp", "http", "https", "mailto"]).addProtocols("blockquote", "cite", ["http", "https"]).addProtocols("cite", "cite", ["http", "https"]).addProtocols("img", "src", ["http", "https"]).addProtocols("q", "cite", ["http", "https"])
    }
    public static func isValidAnchor(value: String): Bool {
        return value.startsWith("#") && !Regex(".*\\s.*").matches(value)
    }
}

class TagName <: TypedValue & Hashable & Equatable<TagName> {
    init(value: String) {
        super(value)
    }
    public static func valueOf(value: String): TagName {
        return TagName(value.toAsciiLower())
    }
    public operator func ==(other: TagName): Bool { return value == other.value }
}

class AttributeKey <: TypedValue & Hashable & Equatable<AttributeKey> {
    init(value: String) {
        super(value)
    }
    public static func valueOf(value: String): AttributeKey {
        return AttributeKey(value.toAsciiLower())
    }
    public operator func ==(other: AttributeKey): Bool { return value == other.value }
}

class AttributeValue <: TypedValue & Hashable & Equatable<AttributeValue> {
    init(value: String) {
        super(value)
    }
    public static func valueOf(value: String): AttributeValue {
        return AttributeValue(value)
    }
    public operator func ==(other: AttributeValue): Bool { return value == other.value }
}

class Protocol <: TypedValue & Hashable & Equatable<Protocol> {
    init(value: String) {
        super(value)
    }
    public static func valueOf(value: String): Protocol {
        return Protocol(value)
    }
    public operator func ==(other: Protocol): Bool { return value == other.value }
}

abstract class TypedValue <: ToString & Hashable {
    let value: String
    init(value: String) {
        this.value = value
    }
    public open func hash(): Int64 {
        return value.hashCode()
    }
    public open func hashCode(): Int64 {
        return value.hashCode()
    }
    public open func equals(other: ?Object): Bool {
        if (other.isNone()) { return false }
        let obj = (other.getOrThrow() as TypedValue)
        if (let Some(o) <- obj) { return value == o.value }
        return false
    }
    public open override func toString(): String {
        return value
    }
}

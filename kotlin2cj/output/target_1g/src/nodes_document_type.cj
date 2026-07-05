package target_1g

class DocumentType <: LeafNode {
    let name: String
    let publicId: String
    let systemId: String
    init(name: String, publicId: String, systemId: String) {
        super(name)
        this.name = name
        this.publicId = publicId
        this.systemId = systemId
        attributes().add(DocumentType.NameKey, name).add(DocumentType.PublicId, publicId).add(DocumentType.SystemId, systemId)
        updatePubSyskey()
    }
    func setPubSysKey(value: ?String) {
        if (let Some(valueValue) <- value) {
            let value = valueValue
            attr(DocumentType.PubSysKey, value)
        }
    }
    func updatePubSyskey() {
        if (has(DocumentType.PublicId)) {
            attributes().add(DocumentType.PubSysKey, DocumentType.PUBLIC_KEY)
        } else if (has(DocumentType.SystemId)) {
            attributes().add(DocumentType.PubSysKey, DocumentType.SYSTEM_KEY)
        }
    }
    public override func nodeName(): String {
        return "#doctype"
    }
    public override func outerHtmlHead(accum: QuietAppendable, out: Document.OutputSettings) {
        if (((out.syntax() == Syntax.html) && !has(DocumentType.PublicId)) && !has(DocumentType.SystemId)) {
            accum.append("<!doctype")
        } else {
            accum.append("<!DOCTYPE")
        }
        if (has(DocumentType.NameKey)) {
            accum.append(" ").append(attr(DocumentType.NameKey))
        }
        if (has(DocumentType.PubSysKey)) {
            accum.append(" ").append(attr(DocumentType.PubSysKey))
        }
        if (has(DocumentType.PublicId)) {
            accum.append(" \"").append(attr(DocumentType.PublicId)).append(r'"')
        }
        if (has(DocumentType.SystemId)) {
            accum.append(" \"").append(attr(DocumentType.SystemId)).append(r'"')
        }
        accum.append(r'>')
    }
    public override func createClone(): Node {
        return DocumentType(this.name, this.publicId, this.systemId)
    }
    func has(attribute: String): Bool {
        return !StringUtil.isBlank(attr(attribute))
    }
    static let PUBLIC_KEY: String = "PUBLIC"
    static let SYSTEM_KEY: String = "SYSTEM"
    static let NameKey: String = "name"
    static let PubSysKey: String = "pubSysKey"
    static let PublicId: String = "publicId"
    static let SystemId: String = "systemId"
}

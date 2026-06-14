package ksoup_cj

class DocumentType <: LeafNode {
    let _name: String
    let _publicId: String
    let _systemId: String
    init(name: String, publicId: String, systemId: String) {
        super(name)
        this._name = name
        this._publicId = publicId
        this._systemId = systemId
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
    func name(): String {
        return attr(DocumentType.NameKey)
    }
    func publicId(): String {
        return attr(DocumentType.PublicId)
    }
    func systemId(): String {
        return attr(DocumentType.SystemId)
    }
    public override func nodeName(): String {
        return "#doctype"
    }
    public override func outerHtmlHead(accum: QuietAppendable, out: OutputSettings) {
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
        return DocumentType(this._name, this._publicId, this._systemId)
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

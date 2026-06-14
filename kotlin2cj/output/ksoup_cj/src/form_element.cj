package ksoup_cj

import std.collection.*

class FormElement <: Element {
    init(tag: Tag, baseUri: ?String, attributes: ?Attributes) {
        super(tag, baseUri, attributes)
    }
    let linkedEls: Elements = Elements()
    let submittable = Selector.evaluatorOf(String.join(collectArray<String>(SharedConstants.FormSubmitTags.iterator().map({e => e.toString()})), delimiter: ", "))
    func elements(): Elements {
        let els = select(submittable)
        for (linkedEl in linkedEls) {
            if ((linkedEl.ownerDocument().isSome()) && !els.contains(linkedEl)) {
                els.add(linkedEl)
            }
        }
        return els
    }
    func addElement(element: Element): FormElement {
        linkedEls.add(element)
        return this
    }
    public override func removeChild(out: Node) {
        super.removeChild(out)
        linkedEls.remove(out)
    }
    public override func clone(): FormElement {
        return (super.clone() as FormElement)
    }
}

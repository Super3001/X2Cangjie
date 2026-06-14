package ksoup_cj

import std.collection.*

class Collector {
    private init() {}
    public static let INSTANCE = Collector()
    static func collect(eval: Evaluator, root: Element): Elements {
        let sequence: Sequence<Element> = if (eval.wantsNodes()) {
            streamNodes(eval, root, Element)
        } else {
            stream(eval, root)
        }
        let els = sequence.toCollection(Elements())
        eval.reset()
        return els
    }
    static func stream(evaluator: Evaluator, root: Element): Sequence<Element> {
        evaluator.reset()
        return collectArrayList(root.stream().iterator().filter(evaluator.asPredicate(root)))
    }
    // NOTE: inline reified function omitted — not supported by translator
}

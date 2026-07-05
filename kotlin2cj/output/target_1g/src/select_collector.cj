package target_1g

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
    static func streamNodes<T>(evaluator: Evaluator, root: Element, `type`: KClass<T>): Sequence<T> where T <: Node {
        evaluator.reset()
        return collectArrayList(root.nodeStream(`type`).iterator().filter(evaluator.asNodePredicate(root)))
    }
    static func findFirst(eval: Evaluator, root: Element): ?Element {
        let el = stream(eval, root).get(0)
        eval.reset()
        return el
    }
    static func findFirstNode<T>(eval: Evaluator, root: Element, `type`: KClass<T>): ?T where T <: Node {
        let node = streamNodes(eval, root, `type`).get(0)
        eval.reset()
        return node
    }
    static func collectNodes<T>(evaluator: Evaluator, root: Element, `type`: KClass<T>): Nodes<T> where T <: Node {
        return streamNodes(evaluator, root, `type`).toCollection(Nodes())
    }
}

package ksoup_cj

import std.collection.*

abstract class StructuralEvaluator <: Evaluator {
    let evaluator: Evaluator
    init(evaluator: Evaluator) {
        this.evaluator = evaluator
    }
    var _wantsNodes: Bool = evaluator.wantsNodes()
    public open override func wantsNodes(): Bool {
        return _wantsNodes
    }
    let threadMemo: ThreadLocal<IdentityHashMap<Node, IdentityHashMap<Node, Bool>>> = ThreadLocal({ => IdentityHashMap() })
    public open func memoMatches(root: Element, element: Node): Bool {
        let rootMemo = threadMemo.get()
        let memo = ({ => if (rootMemo.contains(root)) { rootMemo[root] } else { let _v = ({ => IdentityHashMap() })(); rootMemo[root] = _v; _v } })()
        return ({ => if (memo.contains(element)) { memo[element] } else { let _v = ({ => evaluator.matches(root, element) })(); memo[element] = _v; _v } })()
    }
    public open override func reset() {
        threadMemo.get().clear()
        evaluator.reset()
        super.reset()
    }
    public open override func matches(root: Element, element: Element): Bool {
        return evaluateMatch(root, element)
    }
    public open override func matches(root: Element, leafNode: LeafNode): Bool {
        return evaluateMatch(root, leafNode)
    }
    public func evaluateMatch(root: Element, node: Node): Bool
}

class Root <: Evaluator & ToString {
    public open override func matches(root: Element, element: Element): Bool {
        return root == element
    }
    public open override func cost(): Int64 {
        return 1
    }
    public open override func toString(): String {
        return ">"
    }
}

class Has <: StructuralEvaluator & ToString {
    init(evaluator: Evaluator) {
        super(evaluator)
        this.checkSiblings = evalWantsSiblings(evaluator)
    }
    static func NodeIterPool(): SoftPool<NodeIterator<Node>> {
        return SoftPool({ => NodeIterator(TextNode(""), Node) })
    }
    let checkSiblings: Bool
    public open override func matches(root: Element, element: Element): Bool {
        if (checkSiblings) {
            var sib = element.firstElementSibling()
            while (sib.isSome()) {
                if ((sib != element) && evaluator.matches(element, sib)) {
                    return true
                }
                sib = sib.nextElementSibling()
            }
        }
        let it = Has.NodeIterPool().borrow()
        it.restart(element)
        try {
            while (it.hasNext()) {
                let node = it.next()
                if (node == element) {
                    continue
                }
                if (evaluator.matches(element, node)) {
                    return true
                }
            }
        } finally {
            Has.NodeIterPool().release(it)
        }
        return false
    }
    public open override func evaluateMatch(root: Element, node: Node): Bool {
        return false
    }
    public open func evalWantsSiblings(eval: Evaluator): Bool {
        if ((eval is CombiningEvaluator)) {
            for (innerEval in eval.evaluators) {
                if ((innerEval is PreviousSibling) || (innerEval is ImmediatePreviousSibling)) {
                    return true
                }
            }
        }
        return false
    }
    public open override func cost(): Int64 {
        return 10 * evaluator.cost()
    }
    public open override func toString(): String {
        return ":has(${evaluator})"
    }
}

class Is <: StructuralEvaluator & ToString {
    init(evaluator: Evaluator) {
        super(evaluator)
    }
    public open override func evaluateMatch(root: Element, node: Node): Bool {
        return evaluator.matches(root, node)
    }
    public open override func cost(): Int64 {
        return 2 + evaluator.cost()
    }
    public open override func toString(): String {
        return ":is(${evaluator})"
    }
}

class Not <: StructuralEvaluator & ToString {
    init(evaluator: Evaluator) {
        super(evaluator)
    }
    public open override func evaluateMatch(root: Element, node: Node): Bool {
        return !memoMatches(root, node)
    }
    public open override func cost(): Int64 {
        return 2 + evaluator.cost()
    }
    public open override func toString(): String {
        return ":not(${evaluator})"
    }
}

class Ancestor <: StructuralEvaluator & ToString {
    init(evaluator: Evaluator) {
        super(evaluator)
    }
    public open override func evaluateMatch(root: Element, node: Node): Bool {
        if (root == node) {
            return false
        }
        var parent = node.parent()
        while (parent.isSome()) {
            if (memoMatches(root, parent)) {
                return true
            }
            if (parent == root) {
                break
            }
            parent = parent.parent()
        }
        return false
    }
    public open override func cost(): Int64 {
        return 8 * evaluator.cost()
    }
    public open override func toString(): String {
        return "${evaluator} "
    }
}

class ImmediateParentRun <: StructuralEvaluator & ToString {
    init(evaluator: Evaluator) {
        super(evaluator)
        evaluators.add(evaluator)
        _cost += evaluator.cost()
    }
    let evaluators: ArrayList<Evaluator> = ArrayList<Evaluator>()
    var _cost = 2
    public open func add(evaluator: Evaluator) {
        evaluators.add(evaluator)
        _cost += evaluator.cost()
        _wantsNodes = _wantsNodes | evaluator.wantsNodes()
    }
    public open override func evaluateMatch(root: Element, node: Node): Bool {
        var el: ?Node = node
        if (el == root) {
            return false
        }
        for (i in ({ => let _s = collectArrayList((0..evaluators.size).iterator()); _s.reverse(); _s })()) {
            if (el.isNone()) {
                return false
            }
            let eval: Evaluator = evaluators[i]
            if (!eval.matches(root, el)) {
                return false
            }
            el = el.getOrThrow().parent()
        }
        return true
    }
    public open override func cost(): Int64 {
        return _cost
    }
    public open override func reset() {
        for (evaluator in evaluators) {
            evaluator.reset()
        }
        super.reset()
    }
    public open override func toString(): String {
        return StringUtil.join(evaluators, " > ")
    }
}

class PreviousSibling <: StructuralEvaluator & ToString {
    init(evaluator: Evaluator) {
        super(evaluator)
    }
    public open override func evaluateMatch(root: Element, node: Node): Bool {
        if (root == node) {
            return false
        }
        var sibling = node.firstSibling()
        while (sibling.isSome()) {
            if (sibling == node) {
                break
            }
            if (memoMatches(root, sibling)) {
                return true
            }
            sibling = sibling.nextElementSibling()
        }
        return false
    }
    public open override func cost(): Int64 {
        return 3 * evaluator.cost()
    }
    public open override func toString(): String {
        return "${evaluator} ~ "
    }
}

class ImmediatePreviousSibling <: StructuralEvaluator & ToString {
    init(evaluator: Evaluator) {
        super(evaluator)
    }
    public open override func evaluateMatch(root: Element, node: Node): Bool {
        if (root == node) {
            return false
        }
        let prev = if (_wantsNodes) {
            node.previousSibling()
        } else {
            node.previousElementSibling()
        }
        return (prev.isSome()) && memoMatches(root, prev)
    }
    public open override func cost(): Int64 {
        return 2 + evaluator.cost()
    }
    public open override func toString(): String {
        return "${evaluator} + "
    }
}

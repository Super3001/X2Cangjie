package target_1g

import std.collection.*

abstract class CombiningEvaluator <: Evaluator {
    init() {}
    let evaluators: ArrayList<Evaluator> = ArrayList()
    let sortedEvaluators: ArrayList<Evaluator> = ArrayList()
    var num: Int64 = 0
    var _cost = 0
    var _wantsNodes: Bool = false
    init(evaluators: ArrayList<Evaluator>) {
        this()
        this.evaluators.add(all: evaluators)
        updateEvaluators()
    }
    public open func add(e: Evaluator) {
        evaluators.add(e)
        updateEvaluators()
    }
    public open override func reset() {
        for (evaluator in evaluators) {
            evaluator.reset()
        }
        super.reset()
    }
    public open override func cost(): Int64 {
        return _cost
    }
    public open override func wantsNodes(): Bool {
        return _wantsNodes
    }
    public open func updateEvaluators() {
        num = evaluators.size
        _cost = 0
        for (evaluator in evaluators) {
            _cost += evaluator.cost()
        }
        sortedEvaluators.clear()
        sortedEvaluators.add(all: evaluators)
        sortedEvaluators.sortWith({ a, b => a.cost() - b.cost() })
        for (evaluator in evaluators) {
            if (evaluator.wantsNodes()) {
                _wantsNodes = true
                break
            }
        }
    }
}

class And <: CombiningEvaluator & ToString {
    init(evaluators: ArrayList<Evaluator>) {
        super(evaluators)
    }
    init(evaluators: Array<Evaluator>) {
        this(collectArrayList(evaluators))
    }
    public open override func matches(root: Element, element: Element): Bool {
        for (i in 0..num) {
            let eval = sortedEvaluators[i]
            if (!eval.matches(root, element)) {
                return false
            }
        }
        return true
    }
    public open override func matches(root: Element, leafNode: LeafNode): Bool {
        for (i in 0..num) {
            let eval = sortedEvaluators[i]
            if (!eval.matches(root, leafNode)) {
                return false
            }
        }
        return true
    }
    public open override func toString(): String {
        return StringUtil.join(evaluators, "")
    }
}

class Or <: CombiningEvaluator & ToString {
    init(evaluators: ArrayList<Evaluator>) {
        super()
        if (num > 1) {
            this.evaluators.add(And(evaluators))
        } else {
            this.evaluators.add(all: evaluators)
        }
        updateEvaluators()
    }
    init(evaluators: Array<Evaluator>) {
        this(collectArrayList(evaluators))
    }
    init() {
        super()
    }
    public open override func matches(root: Element, element: Element): Bool {
        for (i in 0..num) {
            let eval = sortedEvaluators[i]
            if (eval.matches(root, element)) {
                return true
            }
        }
        return false
    }
    public open override func matches(root: Element, leafNode: LeafNode): Bool {
        for (i in 0..num) {
            let eval = sortedEvaluators[i]
            if (eval.matches(root, leafNode)) {
                return true
            }
        }
        return false
    }
    public open override func toString(): String {
        return StringUtil.join(evaluators, ", ")
    }
}

package target_1g

abstract class NodeEvaluator <: Evaluator {
    public open override func matches(root: Element, element: Element): Bool {
        return evaluateMatch(element)
    }
    public open override func matches(root: Element, leafNode: LeafNode): Bool {
        return evaluateMatch(leafNode)
    }
    public func evaluateMatch(node: Node): Bool
    public open override func wantsNodes(): Bool {
        return true
    }
}

class InstanceType <: NodeEvaluator & ToString {
    let `type`: kotlin.reflect.KClass<Node>
    let selector: String
    init(`type`: kotlin.reflect.KClass<Node>, selector: String) {
        this.`type` = `type`
        this.selector = selector
    }
    public open override func evaluateMatch(node: Node): Bool {
        return `type`.isInstance(node)
    }
    public open override func cost(): Int64 {
        return 1
    }
    public open override func toString(): String {
        return "::${selector}"
    }
}

class ContainsValue <: NodeEvaluator & ToString {
    init(searchText: String) {
        this.searchText = lowerCase(normaliseWhitespace(searchText))
    }
    let searchText: String
    public open override func evaluateMatch(node: Node): Bool {
        return lowerCase(node.nodeValue()).contains(searchText)
    }
    public open override func cost(): Int64 {
        return 6
    }
    public open override func toString(): String {
        return ":contains(${searchText})"
    }
}

class BlankValue <: NodeEvaluator & ToString {
    public open override func evaluateMatch(node: Node): Bool {
        return StringUtil.isBlank(node.nodeValue())
    }
    public open override func cost(): Int64 {
        return 4
    }
    public open override func toString(): String {
        return ":blank"
    }
}

class MatchesValue <: NodeEvaluator & ToString {
    let pattern: Regex
    init(pattern: Regex) {
        this.pattern = pattern
    }
    public open override func evaluateMatch(node: Node): Bool {
        return ({ => for (_e in pattern) { if ((node.nodeValue())(_e)) { return _e } }; return None })().isSome()
    }
    public open override func cost(): Int64 {
        return 8
    }
    public open override func toString(): String {
        return ":matches(${pattern.pattern})"
    }
}

package target_1g

import std.collection.*

class Selector {
    private init() {}
    public static let INSTANCE = Selector()
    static func select(query: String, root: Element): Elements {
        Validate.notEmpty(query)
        return select(evaluatorOf(query), root)
    }
    static func select(evaluator: Evaluator, root: Element): Elements {
        return Collector.collect(evaluator, root)
    }
    static func selectStream(query: String, root: Element): Sequence<Element> {
        Validate.notEmpty(query)
        return selectStream(evaluatorOf(query), root)
    }
    static func selectStream(evaluator: Evaluator, root: Element): Sequence<Element> {
        return Collector.stream(evaluator, root)
    }
    static func select(query: String, roots: ArrayList<Element>): Elements {
        Validate.notEmpty(query)
        let evaluator = evaluatorOf(query)
        let elements = Elements()
        let seenElements: HashSet<?Element> = HashSet()
        for (root in roots) {
            for (_e in collectArrayList(selectStream(evaluator, root).iterator().filter(seenElements.add))) { (elements.add)(_e) }
        }
        return elements
    }
    static func filterOut(elements: ArrayList<Element>, outs: ArrayList<?Element>): Elements {
        let output = Elements()
        for (el in elements) {
            var found = false
            for (out in outs) {
                if ((el == out)) {
                    found = true
                    break
                }
            }
            if (!found) {
                output.add(el)
            }
        }
        return output
    }
    static func selectFirst(cssQuery: String, root: Element): ?Element {
        Validate.notEmpty(cssQuery)
        return Collector.findFirst(evaluatorOf(cssQuery), root)
    }
    static func selectFirst(cssQuery: String, roots: ArrayList<Element>): ?Element {
        Validate.notEmpty(cssQuery)
        let evaluator = evaluatorOf(cssQuery)
        for (root in roots) {
            let first = Collector.findFirst(evaluator, root)
            if (let Some(firstValue) <- first) {
                let first = firstValue
                return first
            }
        }
        return None
    }
    static func escapeCssIdentifier(input: String): String {
        return TokenQueue.escapeCssIdentifier(input)
    }
    static func unescapeCssIdentifier(input: String): String {
        return TokenQueue(input).use({ tq => tq.consumeCssIdentifier() })
    }
    static func evaluatorOf(css: String): Evaluator {
        return QueryParser.parse(css)
    }
}

class SelectorParseException <: IllegalStateException {
    var cause: ?Exception = None
    init(msg: ?String) {
        super(msg)
    }
    init(cause: ?Exception, msg: ?String) {
        super(msg, cause)
            this.cause = cause
    }
}

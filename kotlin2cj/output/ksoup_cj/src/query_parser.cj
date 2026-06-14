package ksoup_cj

import std.convert.*

func __k2cjRuneSlice(input: String, start: Int64, end: Int64): String {
    let _r = input.toRuneArray()
    let _out = Array<Rune>(end - start, { _ => r'\u{0000}' })
    var _i = 0
    while (_i < end - start) {
        _out[_i] = _r[start + _i]
        _i++
    }
    String(_out)
}

class QueryParser <: AutoCloseable & ToString {
    init(query: String) {
        Validate.notEmpty(query)
        let trimmedQuery = query.trimAscii({ it => it <= r' ' })
        this.query = trimmedQuery
        tq = TokenQueue(trimmedQuery)
    }
    let tq: TokenQueue
    let query: String
    var inNodeContext = false
    func parse(): Evaluator {
        let eval = parseSelectorGroup()
        tq.consumeWhitespace()
        if (!tq.isEmpty()) {
            throw Selector.SelectorParseException("Could not parse query '${query}': unexpected token at '${tq.remainder()}'")
        }
        return eval
    }
    func parseSelectorGroup(): Evaluator {
        var left = parseSelector()
        while (tq.matchChomp(r',')) {
            let right = parseSelector()
            left = or(left, right)
        }
        return left
    }
    func parseSelector(): Evaluator {
        tq.consumeWhitespace()
        var left: Evaluator
        left = if (tq.matchesAny(QueryParser.Combinators())) {
            StructuralEvaluator.Root()
        } else {
            parseSimpleSequence()
        }
        while (true) {
            var combinator = Rune(UInt32(0))
            if (tq.consumeWhitespace()) {
                combinator = r' '
            }
            if (tq.matchesAny(QueryParser.Combinators())) {
                combinator = tq.consume()
            } else if (tq.matchesAny(QueryParser.SequenceEnders())) {
                break
            }
            if (combinator.code != 0) {
                let right = parseSimpleSequence()
                left = combinator(left, combinator, right)
            } else {
                break
            }
        }
        return left
    }
    func parseSimpleSequence(): Evaluator {
        var left: ?Evaluator = None
        tq.consumeWhitespace()
        if (tq.matchesWord() || tq.matches("*|")) {
            left = byTag()
        } else if (tq.matchChomp(r'*')) {
            left = Evaluator.AllElements()
        }
        while (true) {
            let right: ?Evaluator = parseSubclass()
            if (let Some(rightValue) <- right) {
                let right = rightValue
                left = and(left, right)
            } else {
                break
            }
        }
        if (left.isNone()) {
            throw Selector.SelectorParseException("Could not parse query '${query}': unexpected token at '${tq.remainder()}'")
        }
        return left
    }
    func parseSubclass(): ?Evaluator {
        return if (tq.matchChomp(r'#')) {
            byId()
        } else if (tq.matchChomp(r'.')) {
            byClass()
        } else if (tq.matches(r'[')) {
            byAttribute()
        } else if (tq.matchChomp("::")) {
            return parseNodeSelector()
        } else if (tq.matchChomp(r':')) {
            parsePseudoSelector()
        } else {
            None
        }
    }
    func parsePseudoSelector(): Evaluator {
        let pseudo: String = tq.consumeCssIdentifier()
        return match (pseudo) {
            case "lt" => Evaluator.IndexLessThan(consumeIndex())
            case "gt" => Evaluator.IndexGreaterThan(consumeIndex())
            case "eq" => Evaluator.IndexEquals(consumeIndex())
            case "has" => has()
            case "is" => `is`()
            case "contains" => contains(false)
            case "containsOwn" => contains(true)
            case "containsWholeText" => containsWholeText(false)
            case "containsWholeOwnText" => containsWholeText(true)
            case "containsData" => containsData()
            case "matches" => matches(false)
            case "matchesOwn" => matches(true)
            case "matchesWholeText" => matchesWholeText(false)
            case "matchesWholeOwnText" => matchesWholeText(true)
            case "not" => not()
            case "nth-child" => cssNthChild(false, false)
            case "nth-last-child" => cssNthChild(true, false)
            case "nth-of-type" => cssNthChild(false, true)
            case "nth-last-of-type" => cssNthChild(true, true)
            case "first-child" => Evaluator.IsFirstChild()
            case "last-child" => Evaluator.IsLastChild()
            case "first-of-type" => Evaluator.IsFirstOfType()
            case "last-of-type" => Evaluator.IsLastOfType()
            case "only-child" => Evaluator.IsOnlyChild()
            case "only-of-type" => Evaluator.IsOnlyOfType()
            case "empty" => Evaluator.IsEmpty()
            case "blank" => NodeEvaluator.BlankValue()
            case "root" => Evaluator.IsRoot()
            case "matchText" => Evaluator.MatchText()
            case _ => throw Selector.SelectorParseException("Could not parse query '${query}': unexpected token at '${tq.remainder()}'")}
    }
    func parseNodeSelector(): Evaluator {
        let pseudo = tq.consumeCssIdentifier()
        inNodeContext = true
        var left: Evaluator = match (pseudo) {
            case "node" => InstanceType(Node, pseudo)
            case "leafnode" => InstanceType(LeafNode, pseudo)
            case "text" => InstanceType(TextNode, pseudo)
            case "comment" => InstanceType(Comment, pseudo)
            case "data" => InstanceType(DataNode, pseudo)
            case "cdata" => InstanceType(CDataNode, pseudo)
            case _ => throw Selector.SelectorParseException("Could not parse query '${query}': unknown node type '::${pseudo}'")}
        var right: ?Evaluator
        while ({ it =>
            let _also_it = parseSubclass()
            let _it = _also_it
            right = it
            return _also_it
        }().isSome()) {
            left = and(left, right.getOrThrow())
        }
        inNodeContext = false
        return left
    }
    func byId(): Evaluator {
        let id: String = tq.consumeCssIdentifier()
        Validate.notEmpty(id)
        return Evaluator.Id(id)
    }
    func byClass(): Evaluator {
        let className: String = tq.consumeCssIdentifier()
        Validate.notEmpty(className)
        return Evaluator.Class(className.trimAscii({ it => it <= r' ' }))
    }
    func byTag(): Evaluator {
        var tagName: String = normalize(tq.consumeElementSelector())
        Validate.notEmpty(tagName)
        if (tagName.startsWith("*|")) {
            let plainTag = __k2cjRuneSlice(tagName, 2, tagName.toRuneArray().size)
            return CombiningEvaluator.Or(Evaluator.Tag(plainTag), Evaluator.TagEndsWith(":${plainTag}"))
        } else if (tagName.endsWith("|*")) {
            let ns = "${__k2cjRuneSlice(tagName, 0, tagName.toRuneArray().size - 2)}:"
            return Evaluator.TagStartsWith(ns)
        } else if (tagName.contains("|")) {
            tagName = tagName.replace("|", ":")
        }
        return Evaluator.Tag(tagName)
    }
    func byAttribute(): Evaluator {
        return TokenQueue(tq.chompBalanced(r'[', r']')).use({ cq => evaluatorForAttribute(cq) })
    }
    func evaluatorForAttribute(cq: TokenQueue): Evaluator {
        let key: String = normalize(cq.consumeToAny(QueryParser.AttributeEvals()))
        Validate.notEmpty(key)
        Validate.isFalse(key == "abs:", "Absolute attribute key must have a name")
        cq.consumeWhitespace()
        let eval: Evaluator
        if (cq.isEmpty()) {
            eval = if (key.startsWith("^")) {
                Evaluator.AttributeStarting(__k2cjRuneSlice(key, 1, key.toRuneArray().size))
            } else if (key == "*") {
                Evaluator.AttributeStarting("")
            } else {
                Evaluator.Attribute(key)
            }
        } else {
            if (cq.matchChomp(r'=')) {
                eval = Evaluator.AttributeWithValue(key, cq.remainder())
            } else if (cq.matchChomp("!=")) {
                eval = Evaluator.AttributeWithValueNot(key, cq.remainder())
            } else if (cq.matchChomp("^=")) {
                eval = Evaluator.AttributeWithValueStarting(key, cq.remainder())
            } else if (cq.matchChomp("$=")) {
                eval = Evaluator.AttributeWithValueEnding(key, cq.remainder())
            } else if (cq.matchChomp("*=")) {
                eval = Evaluator.AttributeWithValueContaining(key, cq.remainder())
            } else if (cq.matchChomp("~=")) {
                eval = Evaluator.AttributeWithValueMatching(key, jsSupportedRegex(cq.remainder()))
            } else {
                throw Selector.SelectorParseException("Could not parse attribute query '${query}': unexpected token at '${cq.remainder()}'")
            }
        }
        return eval
    }
    func cssNthChild(last: Bool, ofType: Bool): Evaluator {
        let arg = normalize(consumeParens())
        let (step, offset) = if (arg.equals("odd", true)) {
            (2, 1)
        } else if (arg.equals("even", true)) {
            (2, 0)
        } else {
            (if (let Some(m) <- QueryParser.NthStepOffset().matchEntire(arg)) {
                let signGroup = m.groupValues[2]
                let digitsGroup = m.groupValues[3]
                let offsetGroup = m.groupValues[4]
                let step = if (!(digitsGroup.isEmpty())) {
                    Int64.parse(m.groupValues[1].replaceFirst("^\\+".toRegex(), ""))
                } else {
                    if (signGroup == "-") {
                        -1
                    } else {
                        1
                    }
                }
                let offset = if (!(offsetGroup.isEmpty())) {
                    Int64.parse(offsetGroup.replaceFirst("^\\+".toRegex(), ""))
                } else {
                    0
                }
                (step, offset)
            } ?? if (let Some(m) <- QueryParser.NthOffset().matchEntire(arg)) {
                let off = Int64.parse(m.value.replaceFirst("^\\+".toRegex(), ""))
                (0, off)
            }) ?? throw
            Selector.SelectorParseException("Could not parse nth-index '${arg}': unexpected format")
        }
        return if (ofType && last) {
            Evaluator.IsNthLastOfType(step, offset)
        } else if (ofType) {
            Evaluator.IsNthOfType(step, offset)
        } else if (last) {
            Evaluator.IsNthLastChild(step, offset)
        } else {
            Evaluator.IsNthChild(step, offset)
        }
    }
    func consumeParens(): String {
        return tq.chompBalanced(r'(', r')')
    }
    func consumeIndex(): Int64 {
        let index = consumeParens().trimAscii({ it => it <= r' ' })
        isTrue(StringUtil.isNumeric(index), "Index must be numeric")
        return Int64.parse(index)
    }
    func has(): Evaluator {
        return parseNested({ it => StructuralEvaluator.Has(it) }, ":has() must have a selector")
    }
    func `is`(): Evaluator {
        return parseNested({ it => StructuralEvaluator.Is(it) }, ":is() must have a selector")
    }
    func parseNested(`func`: (Evaluator) -> StructuralEvaluator, err: ?String): Evaluator {
        isTrue(tq.matchChomp(r'('), err)
        let eval: Evaluator = parseSelectorGroup()
        isTrue(tq.matchChomp(r')'), err)
        return `func`(eval)
    }
    func contains(own: Bool): Evaluator {
        let query = if (own) {
            ":containsOwn"
        } else {
            ":contains"
        }
        let searchText: String = TokenQueue.unescape(consumeParens())
        Validate.notEmpty(searchText, "${query}(text) query must not be empty")
        if (inNodeContext) {
            return ContainsValue(searchText)
        }
        return if (own) {
            Evaluator.ContainsOwnText(searchText)
        } else {
            Evaluator.ContainsText(searchText)
        }
    }
    func containsWholeText(own: Bool): Evaluator {
        let query = if (own) {
            ":containsWholeOwnText"
        } else {
            ":containsWholeText"
        }
        let searchText: String = TokenQueue.unescape(consumeParens())
        Validate.notEmpty(searchText, "${query}(text) query must not be empty")
        return if (own) {
            Evaluator.ContainsWholeOwnText(searchText)
        } else {
            Evaluator.ContainsWholeText(searchText)
        }
    }
    func containsData(): Evaluator {
        let searchText: String = TokenQueue.unescape(consumeParens())
        Validate.notEmpty(searchText, ":containsData(text) query must not be empty")
        return Evaluator.ContainsData(searchText)
    }
    func matches(own: Bool): Evaluator {
        let query = if (own) {
            ":matchesOwn"
        } else {
            ":matches"
        }
        let regex = consumeParens()
        Validate.notEmpty(regex, "${query}(regex) query must not be empty")
        let compiled = jsSupportedRegex(regex)
        return if (inNodeContext) {
            NodeEvaluator.MatchesValue(compiled)
        } else if (own) {
            Evaluator.MatchesOwn(compiled)
        } else {
            Evaluator.Matches(compiled)
        }
    }
    func matchesWholeText(own: Bool): Evaluator {
        let query = if (own) {
            ":matchesWholeOwnText"
        } else {
            ":matchesWholeText"
        }
        let regex = consumeParens()
        Validate.notEmpty(regex, "${query}(regex) query must not be empty")
        let pattern = jsSupportedRegex(regex)
        return if (own) {
            Evaluator.MatchesWholeOwnText(pattern)
        } else {
            Evaluator.MatchesWholeText(pattern)
        }
    }
    func not(): Evaluator {
        let subQuery = consumeParens()
        Validate.notEmpty(subQuery, ":not(selector) subselect must not be empty")
        return StructuralEvaluator.Not(parse(subQuery))
    }
    public override func toString(): String {
        return query
    }
    public override func close() {
        tq.close()
    }
    static func Combinators(): Array<Rune> {
        return [r'>', r'+', r'~']
    }
    static func SequenceEnders(): Array<Rune> {
        return [r',', r')']
    }
    static func AttributeEvals(): __ArrayLiteral<String> {
        return ["=", "!=", "^=", "$=", "*=", "~="]
    }
    static func parse(query: String): Evaluator {
        return try {
            QueryParser(query).use({ it => it.parse() })
        } catch (e: IllegalArgumentException) {
            throw Selector.SelectorParseException(e.message)
        }
    }
    static func combinator(left: Evaluator, combinator: Rune, right: Evaluator): Evaluator {
        match (combinator) {
            case r'>' => 
                let run = (if (left is ImmediateParentRun) { left as ImmediateParentRun } else { None }) ?? ImmediateParentRun(left)
                run.add(right)
                return run
            case r' ' => return and(StructuralEvaluator.Ancestor(left), right)
            case r'+' => return and(StructuralEvaluator.ImmediatePreviousSibling(left), right)
            case r'~' => return and(StructuralEvaluator.PreviousSibling(left), right)
            case _ => throw Selector.SelectorParseException("Unknown combinator '${combinator}'")}
    }
    static func or(left: Evaluator, right: Evaluator): Evaluator {
        if ((left is CombiningEvaluator.Or)) {
            left.add(right)
            return left
        }
        return CombiningEvaluator.Or(left, right)
    }
    static func and(left: ?Evaluator, right: Evaluator): Evaluator {
        if (left.isNone()) {
            return right
        }
        if ((left is CombiningEvaluator.And)) {
            left.getOrThrow().add(right)
            return left
        }
        return CombiningEvaluator.And(left, right)
    }
    static func NthStepOffset(): Regex {
        return Regex("(([+-])?(\\d+)?)n(\\s*([+-])?\\s*\\d+)?", RegexOption.IGNORE_CASE)
    }
    static func NthOffset(): Regex {
        return Regex("([+-])?(\\d+)")
    }
}

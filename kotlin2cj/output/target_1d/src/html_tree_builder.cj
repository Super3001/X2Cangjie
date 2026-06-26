package target_1d

import std.collection.*
import std.convert.*

open class HtmlTreeBuilder <: TreeBuilder & ToString {
    var _state: ?HtmlTreeBuilderState = None
    var _originalState: ?HtmlTreeBuilderState = None
    var baseUriSetFromDoc = false
    var headElement: ?Element = None
    var formElement: ?FormElement = None
    var contextElement: ?Element = None
    var formattingElements: ArrayList<?Element> = ArrayList()
    var tmplInsertMode: ?ArrayList<HtmlTreeBuilderState> = None
    var pendingTableCharacters: ?ArrayList<Token.Character> = None
    var emptyEnd: ?Token.EndTag = None
    var _framesetOk = false
    var isFosterInserts: Bool = false
    var isFragmentParsing: Bool = false
    public open override func defaultSettings(): ParseSettings {
        return ParseSettings.htmlDefault
    }
    public open override func newInstance(): HtmlTreeBuilder {
        return HtmlTreeBuilder()
    }
    public open override func initialiseParse(input: Reader, baseUri: String, parser: Parser) {
        super.initialiseParse(input, baseUri, parser)
        _state = HtmlTreeBuilderState.Initial
        _originalState = None
        baseUriSetFromDoc = false
        headElement = None
        formElement = None
        contextElement = None
        tmplInsertMode = ArrayList()
        pendingTableCharacters = ArrayList()
        emptyEnd = EndTag(this)
        _framesetOk = true
        isFosterInserts = false
        isFragmentParsing = false
    }
    public open override func initialiseParseFragment(context: ?Element) {
        _state = HtmlTreeBuilderState.Initial
        isFragmentParsing = true
        if (let Some(contextValue) <- context) {
            let context = contextValue
            let contextName = context.normalName()
            contextElement = Element(tagFor(contextName, contextName, defaultNamespace(), settings), baseUri)
            if (context.ownerDocument().isSome()) {
                doc.quirksMode(context.ownerDocument().getOrThrow().quirksMode())
            }
            match (contextName) {
                case "script" => tokeniser.transition(TokeniserState.ScriptData)
                case "plaintext" => tokeniser.transition(TokeniserState.PLAINTEXT)
                case "template" => 
                    tokeniser?.transition(TokeniserState.Data)
                    pushTemplateMode(HtmlTreeBuilderState.InTemplate)
                case _ => 
                    let tag = contextElement.getOrThrow().tag()
                    let textState = tag.textState()
                    if (let Some(textStateValue) <- textState) {
                        let textState = textStateValue
                        tokeniser.transition(textState)
                    } else {
                        tokeniser.transition(TokeniserState.Data)
                    }}
            doc.appendChild(contextElement.getOrThrow())
            push(contextElement.getOrThrow())
            resetInsertionMode()
            var formSearch: ?Element = context
            while (formSearch.isSome()) {
                if ((formSearch is FormElement)) {
                    formElement = formSearch
                    break
                }
                formSearch = formSearch.getOrThrow().parent()
            }
        }
    }
    public open override func completeParseFragment(): ArrayList<Node> {
        return if (let Some(contextElementValue) <- contextElement) {
            let contextElement = contextElementValue
            let nodes = contextElement.getOrThrow().siblingNodes()
            if (!(nodes.isEmpty())) {
                contextElement.getOrThrow().insertChildren(-1, nodes)
            }
            contextElement.getOrThrow().childNodes()
        } else {
            doc.childNodes()
        }
    }
    public open override func process(token: Token): Bool {
        let dispatch = if (useCurrentOrForeignInsert(token)) {
            this.state
        } else {
            ForeignContent
        }
        return dispatch.process(token, this)
    }
    public open func useCurrentOrForeignInsert(token: Token): Bool {
        if (getStack().isEmpty()) {
            return true
        }
        let el: Element = currentElement()
        let ns: String = el.tag().namespace()
        if (NamespaceHtml == ns) {
            return true
        }
        if (isMathmlTextIntegration(el)) {
            if ((token.isStartTag() && ("mglyph" != token.asStartTag().normalName)) && ("malignmark" != token.asStartTag().normalName)) {
                return true
            }
            if (token.isCharacter()) {
                return true
            }
        }
        if ((((Parser.NamespaceMathml == ns) && el.nameIs("annotation-xml")) && token.isStartTag()) && ("svg" == token.asStartTag().normalName)) {
            return true
        }
        return if (isHtmlIntegration(el) && (token.isStartTag() || token.isCharacter())) {
            true
        } else {
            token.isEOF()
        }
    }
    public open func process(token: Token, state: HtmlTreeBuilderState): Bool {
        return state.process(token, this)
    }
    public open func transition(state: ?HtmlTreeBuilderState) {
        this.state = state
    }
    public open func state(): ?HtmlTreeBuilderState {
        return _state
    }
    public open func markInsertionMode() {
        _originalState = _state
    }
    public open func originalState(): ?HtmlTreeBuilderState {
        return _originalState
    }
    public open func framesetOk(framesetOk: Bool): Unit {
        this.framesetOk = framesetOk
    }
    public open func framesetOk(): Bool {
        return _framesetOk
    }
    let document: Document
    public open func maybeSetBaseUri(base: Element) {
        if (baseUriSetFromDoc) {
            return
        }
        let href: String = base.absUrl("href")
        if (!(href.isEmpty())) {
            baseUri = href
            baseUriSetFromDoc = true
            doc.setBaseUri(href)
        }
    }
    public open func error(state: ?HtmlTreeBuilderState) {
        if (parser.getErrors().canAddError()) {
            parser.getErrors().add(ParseError(reader, "Unexpected ${currentToken.tokenType()} token [${currentToken}] when in state [${state}]"))
        }
    }
    public open func createElementFor(startTag: Token.StartTag, namespace: String, forcePreserveCase: Bool): Element {
        let attributes = startTag.attributes
        if ((attributes.isSome()) && !attributes.isEmpty()) {
            if (!forcePreserveCase) {
                settings.normalizeAttributes(attributes)
            }
            let dupes = attributes.deduplicate(settings)
            if (dupes > 0) {
                error("Dropped duplicate attribute(s) in tag [${startTag.normalName}]")
            }
        }
        let tag: Tag = tagFor(startTag.name(), startTag.normalName, namespace, if (forcePreserveCase) {
            ParseSettings.preserveCase
        } else {
            settings
        })
        return if (tag.normalName() == "form") {
            FormElement(tag, None, attributes)
        } else {
            Element(tag, None, attributes)
        }
    }
    public open func insertElementFor(startTag: Token.StartTag): Element {
        let el: Element = createElementFor(startTag, NamespaceHtml, false)
        doInsertElement(el)
        if (startTag.selfClosing) {
            let tag: Tag = el.tag()
            tag.setSeenSelfClose()
            if (tag.isEmpty()) {} else if (tag.isKnownTag() && tag.isSelfClosing()) {
                tokeniser.transition(TokeniserState.Data)
                tokeniser.emit(emptyEnd.getOrThrow().reset().name(el.tagName()))
            } else {
                tokeniser.error("Tag [${tag.normalName()}] cannot be self-closing; not a void tag")
            }
        }
        if (el.tag().isEmpty()) {
            pop()
        }
        return el
    }
    public open func insertForeignElementFor(startTag: Token.StartTag, namespace: String): Element {
        let el: Element = createElementFor(startTag, namespace, true)
        doInsertElement(el)
        if (startTag.selfClosing) {
            el.tag().setSeenSelfClose()
            pop()
        }
        return el
    }
    public open func insertEmptyElementFor(startTag: Token.StartTag): Element {
        let el = createElementFor(startTag, NamespaceHtml, false)
        doInsertElement(el)
        pop()
        return el
    }
    public open func insertFormElement(startTag: Token.StartTag, onStack: Bool, checkTemplateStack: Bool): FormElement {
        let el = (createElementFor(startTag, NamespaceHtml, false) as FormElement)
        if (checkTemplateStack) {
            if (!onStack("template")) {
                setFormElement(el)
            }
        } else {
            setFormElement(el)
        }
        doInsertElement(el)
        if (!onStack) {
            pop()
        }
        return el
    }
    public open func doInsertElement(el: Element) {
        enforceStackDepthLimit()
        if (((formElement.isSome()) && (el.tag().namespace() == NamespaceHtml)) && StringUtil.inSorted(el.normalName(), HtmlTreeBuilder.TagFormListed())) {
            formElement.getOrThrow().addElement(el)
        }
        if ((parser.getErrors().canAddError() && el.hasAttr("xmlns")) && (el.attr("xmlns") != el.tag().namespace())) {
            error("Invalid xmlns attribute [${el.attr("xmlns")}] on tag [${el.tagName()}]")
        }
        if (isFosterInserts && StringUtil.inSorted(currentElement().normalName(), InTableFoster)) {
            insertInFosterParent(el)
        } else {
            currentElement().appendChild(el)
        }
        push(el)
    }
    public open func insertCommentNode(token: Token.Comment) {
        let node = Comment(token.getData())
        currentElement().appendChild(node)
        onNodeInserted(node)
    }
    public open func insertCharacterNode(characterToken: Token.Character): Unit {
        insertCharacterNode(characterToken, false)
    }
    public open func insertCharacterNode(characterToken: Token.Character, replace: Bool) {
        characterToken.normalizeNulls(replace)
        let el = currentElement()
        insertCharacterToElement(characterToken, el)
    }
    public open func insertCharacterToElement(characterToken: Token.Character, el: Element) {
        let node: Node
        let data: String = characterToken.getData()
        node = if (characterToken.isCData()) {
            CDataNode(data)
        } else if (el.tag().`is`(Tag.Data)) {
            DataNode(data)
        } else {
            TextNode(data)
        }
        el.appendChild(node)
        onNodeInserted(node)
    }
    public open func onStack(el: Element): Bool {
        return onStack(getStack(), el)
    }
    public open func onStack(elName: ?String): Bool {
        return getFromStack(elName).isSome()
    }
    public open func getFromStack(elName: ?String): ?Element {
        let bottom: Int64 = getStack().size - 1
        let upper = if (bottom >= HtmlTreeBuilder.maxQueueDepth) {
            bottom - HtmlTreeBuilder.maxQueueDepth
        } else {
            0
        }
        for (pos in bottom..=upper : -1) {
            let next: ?Element = getStack()[pos]
            if (next?.elementIs(elName, NamespaceHtml) == true) {
                return next
            }
        }
        return None
    }
    public open func removeFromStack(el: Element): Bool {
        for (pos in (getStack().size - 1)..=0 : -1) {
            let next: Element = getStack()[pos]
            if (next == el) {
                getStack().remove(at: pos)
                onNodeClosed(el)
                return true
            }
        }
        return false
    }
    public open override func onStackPrunedForDepth(element: Element) {
        if (element == headElement) {
            headElement = None
        }
        if (element == formElement) {
            setFormElement(None)
        }
        removeFromActiveFormattingElements(element)
        if (element.nameIs("template")) {
            clearFormattingElementsToLastMarker()
            if (templateModeSize() > 0) {
                popTemplateMode()
            }
            resetInsertionMode()
        }
    }
    public open func popStackToClose(elName: String): ?Element {
        for (pos in (getStack().size - 1)..=0 : -1) {
            let el: ?Element = pop()
            if (el?.elementIs(elName, NamespaceHtml) == true) {
                return el
            }
        }
        return None
    }
    public open func popStackToCloseAnyNamespace(elName: String): ?Element {
        for (pos in (getStack().size - 1)..=0 : -1) {
            let el: ?Element = pop()
            if (el?.nameIs(elName) == true) {
                return el
            }
        }
        return None
    }
    public open func popStackToClose(elNames: Array<String>) {
        for (pos in (getStack().size - 1)..=0 : -1) {
            let el: Element = pop().getOrThrow()
            if (StringUtil.inSorted(el.normalName(), elNames) && (NamespaceHtml == el.tag().namespace())) {
                break
            }
        }
    }
    public open func clearStackToTableContext() {
        clearStackToContext(["table", "template"])
    }
    public open func clearStackToTableBodyContext() {
        clearStackToContext(["tbody", "tfoot", "thead", "template"])
    }
    public open func clearStackToTableRowContext() {
        clearStackToContext(["tr", "template"])
    }
    public open func clearStackToContext(nodeNames: Array<String>) {
        for (pos in (getStack().size - 1)..=0 : -1) {
            let next: ?Element = getStack()[pos]
            if ((NamespaceHtml == next?.tag()?.namespace()) && (StringUtil.isIn(next.getOrThrow().normalName(), nodeNames) || next.getOrThrow().nameIs("html"))) {
                break
            } else {
                pop()
            }
        }
    }
    public open func aboveOnStack(el: Element): ?Element {
        if (!onStack(el)) {
            return None
        }
        for (pos in (getStack().size - 1)..=1 : -1) {
            let next: ?Element = getStack()[pos]
            if (next == el) {
                return getStack()[pos - 1]
            }
        }
        return None
    }
    public open func insertOnStackAfter(after: Element, inEl: Element) {
        let i: Int64 = _stack.lastIndexOf(after)
        if (i == -1) {
            error("Did not find element on stack to insert after")
            _stack?.add(inEl)
        } else {
            _stack?.add(i + 1, inEl)
        }
    }
    public open func replaceOnStack(out: Element, inEl: Element) {
        replaceInQueue(getStack(), out, inEl)
    }
    public open func resetInsertionMode(): Bool {
        var last = false
        let bottom: Int64 = getStack().size - 1
        let upper = if (bottom >= HtmlTreeBuilder.maxQueueDepth) {
            bottom - HtmlTreeBuilder.maxQueueDepth
        } else {
            0
        }
        let origState: ?HtmlTreeBuilderState = _state
        if (getStack().size == 0) {
            transition(HtmlTreeBuilderState.InBody)
        }
        LOOP
        { =>
            var node: ?Element = getStack()[pos]
            if (pos == upper) {
                last = true
                if (isFragmentParsing) {
                    node = contextElement
                }
            }
            let name = node?.normalName() ?? ""
            if (NamespaceHtml != node.getOrThrow().tag().namespace()) {
                continue
            }
            match (name) {
                case "select" => 
                    transition(HtmlTreeBuilderState.InSelect)
                    break
                case "td" | "th" => 
                    if (!last) {
                        transition(HtmlTreeBuilderState.InCell)
                        break
                    }
                case "tr" => 
                    transition(HtmlTreeBuilderState.InRow)
                    break
                case "tbody" | "thead" | "tfoot" => 
                    transition(HtmlTreeBuilderState.InTableBody)
                    break
                case "caption" => 
                    transition(HtmlTreeBuilderState.InCaption)
                    break
                case "colgroup" => 
                    transition(HtmlTreeBuilderState.InColumnGroup)
                    break
                case "table" => 
                    transition(HtmlTreeBuilderState.InTable)
                    break
                case "template" => 
                    let tmplState: ?HtmlTreeBuilderState = currentTemplateMode()
                    requireNotNull(tmplState, { => "Bug: no template insertion mode on stack!" })
                    transition(tmplState)
                    break
                case "head" => 
                    if (!last) {
                        transition(HtmlTreeBuilderState.InHead)
                        break
                    }
                case "body" => 
                    transition(HtmlTreeBuilderState.InBody)
                    break
                case "frameset" => 
                    transition(HtmlTreeBuilderState.InFrameset)
                    break
                case "html" => 
                    transition(if (let Some(headElementValue) <- headElement) {
                        let headElement = headElementValue
                        HtmlTreeBuilderState.AfterHead
                    } else {
                        HtmlTreeBuilderState.BeforeHead
                    })
                    break
                case _ => ()}
            if (last) {
                transition(HtmlTreeBuilderState.InBody)
                break
            }
        }
        return _state != origState
    }
    public open func resetBody() {
        if (!onStack("body")) {
            getStack().add(doc.body())
        }
        transition(HtmlTreeBuilderState.InBody)
    }
    let specificScopeTarget = [""]
    public open func inSpecificScope(targetName: String, baseTypes: Array<String>, extraTypes: ?Array<String>): Bool {
        specificScopeTarget[0] = targetName
        return inSpecificScope(specificScopeTarget, baseTypes, extraTypes)
    }
    public open func inSpecificScope(targetNames: Array<String>, baseTypes: Array<String>, extraTypes: ?Array<String>): Bool {
        let bottom: Int64 = _stack.size - 1
        for (pos in bottom..=0 : -1) {
            let el: Element = _stack[pos]
            let elName: String = el.normalName()
            let ns: String = el.tag().namespace()
            if (ns == NamespaceHtml) {
                if (StringUtil.inSorted(elName, targetNames)) {
                    return true
                }
                if (StringUtil.inSorted(elName, baseTypes)) {
                    return false
                }
                if ((extraTypes.isSome()) && StringUtil.inSorted(elName, extraTypes)) {
                    return false
                }
            } else if (baseTypes.contentEquals(HtmlTreeBuilder.TagsSearchInScope())) {
                if ((ns == Parser.NamespaceMathml) && StringUtil.inSorted(elName, HtmlTreeBuilder.TagSearchInScopeMath())) {
                    return false
                }
                if ((ns == Parser.NamespaceSvg) && StringUtil.inSorted(elName, HtmlTreeBuilder.TagSearchInScopeSvg())) {
                    return false
                }
            }
        }
        return false
    }
    public open func inScope(targetNames: Array<String>): Bool {
        return inSpecificScope(targetNames, HtmlTreeBuilder.TagsSearchInScope(), None)
    }
    public open func inScope(targetName: String, extras!: ?Array<String>): Bool {
        return inSpecificScope(targetName, HtmlTreeBuilder.TagsSearchInScope(), extras)
    }
    public open func inListItemScope(targetName: String): Bool {
        return inScope([targetName, HtmlTreeBuilder.TagSearchList()])
    }
    public open func inButtonScope(targetName: String): Bool {
        return inScope([targetName, HtmlTreeBuilder.TagSearchButton()])
    }
    public open func inTableScope(targetName: String): Bool {
        return inSpecificScope(targetName, HtmlTreeBuilder.TagSearchTableScope(), None)
    }
    public open func inSelectScope(targetName: String): Bool {
        for (pos in (getStack().size - 1)..=0 : -1) {
            let el: Element = getStack().get(pos) ?? continue
            let elName: String = el.normalName()
            if (elName == targetName) {
                return true
            }
            if (!StringUtil.inSorted(elName, HtmlTreeBuilder.TagSearchSelectScope())) {
                return false
            }
        }
        return false
    }
    public open func onStackNot(allowedTags: Array<String>): Bool {
        for (pos in (_stack.size - 1)..=0 : -1) {
            let elName: String = _stack[pos].normalName()
            if (!StringUtil.inSorted(elName, allowedTags)) {
                return true
            }
        }
        return false
    }
    public open func setHeadElement(headElement: ?Element) {
        this.headElement = headElement
    }
    public open func getHeadElement(): ?Element {
        return headElement
    }
    public open func getFormElement(): ?FormElement {
        return formElement
    }
    public open func setFormElement(formElement: ?FormElement) {
        this.formElement = formElement
    }
    public open func resetPendingTableCharacters() {
        pendingTableCharacters.clear()
    }
    public open func getPendingTableCharacters(): ?ArrayList<Token.Character> {
        return pendingTableCharacters
    }
    public open func addPendingTableCharacters(c: Token.Character) {
        let copy: Token.Character = Character(c)
        pendingTableCharacters.getOrThrow().add(copy)
    }
    public open func generateImpliedEndTags(excludeTag: ?String) {
        while (StringUtil.inSorted(currentElement().normalName(), HtmlTreeBuilder.TagSearchEndTags())) {
            if ((excludeTag.isSome()) && currentElementIs(excludeTag)) {
                break
            }
            pop()
        }
    }
    public open func generateImpliedEndTags(thorough!: Bool) {
        let search = if (thorough) {
            HtmlTreeBuilder.TagThoroughSearchEndTags()
        } else {
            HtmlTreeBuilder.TagSearchEndTags()
        }
        while ((NamespaceHtml == currentElement().tag().namespace()) && StringUtil.inSorted(currentElement().normalName(), search)) {
            pop()
        }
    }
    public open func closeElement(name: String) {
        generateImpliedEndTags(name)
        if (name != currentElement().normalName()) {
            error(_state())
        }
        popStackToClose(name)
    }
    public open func lastFormattingElement(): ?Element {
        return if (formattingElements.size > 0) {
            formattingElements[formattingElements.size - 1]
        } else {
            None
        }
    }
    public open func positionOfElement(el: ?Element): Int64 {
        for (i in (0..formattingElements.size)) {
            if (el == formattingElements[i]) {
                return i
            }
        }
        return -1
    }
    public open func removeLastFormattingElement(): ?Element {
        let size: Int64 = formattingElements.size
        return if (size > 0) {
            formattingElements.remove(at: size - 1)
        } else {
            None
        }
    }
    public open func pushActiveFormattingElements(`in`: Element) {
        checkActiveFormattingElements(`in`)
        formattingElements.add(`in`)
    }
    public open func pushWithBookmark(`in`: Element, bookmark: Int64) {
        checkActiveFormattingElements(`in`)
        try {
            formattingElements.add(bookmark, `in`)
        } catch (e: IndexOutOfBoundsException) {
            formattingElements.add(`in`)
        }
    }
    public open func checkActiveFormattingElements(`in`: Element) {
        var numSeen = 0
        let size: Int64 = formattingElements.size - 1
        var ceil = size - HtmlTreeBuilder.maxUsedFormattingElements
        if (ceil < 0) {
            ceil = 0
        }
        for (pos in size..=ceil : -1) {
            let el: Element = formattingElements.get(pos) ?? break
            if (isSameFormattingElement(`in`, el)) {
                numSeen += 1
            }
            if (numSeen == 3) {
                formattingElements.remove(at: pos)
                break
            }
        }
    }
    public open func reconstructFormattingElements() {
        if (getStack().size > HtmlTreeBuilder.maxQueueDepth) {
            return
        }
        let last: ?Element = lastFormattingElement()
        if ((last.isNone()) || onStack(last)) {
            return
        }
        var entry: ?Element = last
        let size: Int64 = formattingElements?.size ?? 0
        var ceil = size - HtmlTreeBuilder.maxUsedFormattingElements
        if (ceil < 0) {
            ceil = 0
        }
        var pos = size - 1
        var skip = false
        while (true) {
            if (pos == ceil) {
                skip = true
                break
            }
            entry = formattingElements?.get(pos -= 1)
            if ((entry.isNone()) || onStack(entry)) {
                break
            }
        }
        while (true) {
            if (!skip) {
                entry = formattingElements[pos += 1]
            }
            skip = false
            let newEl = Element(tagFor(entry.getOrThrow().nodeName(), entry.getOrThrow().normalName(), defaultNamespace(), settings), None, entry.getOrThrow().attributes().clone())
            doInsertElement(newEl)
            formattingElements[pos] = newEl
            if (pos == (size - 1)) {
                break
            }
        }
    }
    public open func clearFormattingElementsToLastMarker() {
        while (!formattingElements.isEmpty()) {
            removeLastFormattingElement() ?? break
        }
    }
    public open func removeFromActiveFormattingElements(el: Element) {
        for (pos in ({ => let _s = collectArrayList((0..formattingElements.size).iterator()); _s.reverse(); _s })()) {
            let next: ?Element = formattingElements?.get(pos)
            if (next == el) {
                formattingElements.remove(at: pos)
                break
            }
        }
    }
    public open func isInActiveFormattingElements(el: Element): Bool {
        return onStack(collectArrayList(formattingElements?.mapNotNull({ it => it })) ?? emptyList(), el)
    }
    public open func getActiveFormattingElement(nodeName: ?String): ?Element {
        for (pos in ({ => let _s = collectArrayList((0..formattingElements.size).iterator()); _s.reverse(); _s })()) {
            let next: ?Element = formattingElements?.get(pos)
            if (let Some(nextValue) <- next) {
                let next = nextValue
                if (next.nameIs(nodeName)) {
                    return next
                }
            } else {
                break
            }
        }
        return None
    }
    public open func replaceActiveFormattingElement(out: Element, `in`: Element) {
        replaceInQueue(formattingElements, out, `in`)
    }
    public open func insertMarkerToFormattingElements() {
        formattingElements.add(None)
    }
    public open func insertInFosterParent(inNode: Node) {
        let fosterParent: ?Element
        let lastTable: ?Element = getFromStack("table")
        var isLastTableParent = false
        if (let Some(lastTableValue) <- lastTable) {
            let lastTable = lastTableValue
            if (lastTable.parent().isSome()) {
                fosterParent = lastTable.parent()
                isLastTableParent = true
            } else {
                fosterParent = aboveOnStack(lastTable)
            }
        } else {
            fosterParent = getStack()[0]
        }
        if (isLastTableParent) {
            lastTable.getOrThrow().before(inNode)
        } else {
            fosterParent.getOrThrow().appendChild(inNode)
        }
    }
    public open func pushTemplateMode(state: HtmlTreeBuilderState) {
        tmplInsertMode?.add(state)
    }
    public open func popTemplateMode(): ?HtmlTreeBuilderState {
        return if (!tmplInsertMode.getOrThrow().isNullOrEmpty()) {
            tmplInsertMode.remove(at: tmplInsertMode.getOrThrow().size - 1)
        } else {
            None
        }
    }
    public open func templateModeSize(): Int64 {
        return tmplInsertMode?.size ?? 0
    }
    public open func currentTemplateMode(): ?HtmlTreeBuilderState {
        return if (tmplInsertMode.getOrThrow().size > 0) {
            tmplInsertMode?.get(tmplInsertMode.getOrThrow().size - 1)
        } else {
            None
        }
    }
    public open override func toString(): String {
        return (((((("TreeBuilder{" + "currentToken=") + currentToken.toString()) + ", state=") + _state.toString()) + ", currentElement=") + currentElement().toString()) + r'}'.toString()
    }
    static func TagsSearchInScope(): Array<String> {
        return ["applet", "caption", "html", "marquee", "object", "table", "td", "template", "th"]
    }
    static func TagSearchInScopeMath(): Array<String> {
        return ["annotation-xml", "mi", "mn", "mo", "ms", "mtext"]
    }
    static func TagSearchInScopeSvg(): Array<String> {
        return ["desc", "foreignobject", "title"]
    }
    static func TagSearchList(): Array<String> {
        return ["ol", "ul"]
    }
    static func TagSearchButton(): Array<String> {
        return ["button"]
    }
    static func TagSearchTableScope(): Array<String> {
        return ["html", "table"]
    }
    static func TagSearchSelectScope(): Array<String> {
        return ["optgroup", "option"]
    }
    static func TagSearchEndTags(): Array<String> {
        return ["dd", "dt", "li", "optgroup", "option", "p", "rb", "rp", "rt", "rtc"]
    }
    static func TagThoroughSearchEndTags(): Array<String> {
        return ["caption", "colgroup", "dd", "dt", "li", "optgroup", "option", "p", "rb", "rp", "rt", "rtc", "tbody", "td", "tfoot", "th", "thead", "tr"]
    }
    static func TagSearchSpecial(): Array<String> {
        return ["address", "applet", "area", "article", "aside", "base", "basefont", "bgsound", "blockquote", "body", "br", "button", "caption", "center", "col", "colgroup", "dd", "details", "dir", "div", "dl", "dt", "embed", "fieldset", "figcaption", "figure", "footer", "form", "frame", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hgroup", "hr", "html", "iframe", "img", "input", "keygen", "li", "link", "listing", "main", "marquee", "menu", "meta", "nav", "noembed", "noframes", "noscript", "object", "ol", "p", "param", "plaintext", "pre", "script", "search", "section", "select", "source", "style", "summary", "table", "tbody", "td", "template", "textarea", "tfoot", "th", "thead", "title", "tr", "track", "ul", "wbr", "xmp"]
    }
    static func TagSearchSpecialMath(): Array<String> {
        return ["annotation-xml", "mi", "mn", "mo", "ms", "mtext"]
    }
    static func TagMathMlTextIntegration(): Array<String> {
        return ["mi", "mn", "mo", "ms", "mtext"]
    }
    static func TagSvgHtmlIntegration(): Array<String> {
        return ["desc", "foreignObject", "title"]
    }
    static func TagFormListed(): Array<String> {
        return ["button", "fieldset", "input", "keygen", "object", "output", "select", "textarea"]
    }
    static let MaxScopeSearchDepth: Int64 = 100
    static let maxQueueDepth: Int64 = 256
    public static func onStack(queue: ArrayList<?Element>, element: Element): Bool {
        let bottom: Int64 = queue.size - 1
        let upper = if (bottom >= HtmlTreeBuilder.maxQueueDepth) {
            bottom - HtmlTreeBuilder.maxQueueDepth
        } else {
            0
        }
        for (pos in bottom..=upper : -1) {
            let next: ?Element = queue[pos]
            if (next == element) {
                return true
            }
        }
        return false
    }
    static let maxUsedFormattingElements = 12
    public static func isMathmlTextIntegration(el: Element): Bool {
        return (Parser.NamespaceMathml == el.tag().namespace()) && StringUtil.inSorted(el.normalName(), HtmlTreeBuilder.TagMathMlTextIntegration())
    }
    public static func isHtmlIntegration(el: Element): Bool {
        if ((Parser.NamespaceMathml == el.tag().namespace()) && el.nameIs("annotation-xml")) {
            let encoding: String = Normalizer.normalize(el.attr("encoding"))
            if ((encoding == "text/html") || (encoding == "application/xhtml+xml")) {
                return true
            }
        }
        return (Parser.NamespaceSvg == el.tag().namespace()) && StringUtil.isIn(el.tagName(), HtmlTreeBuilder.TagSvgHtmlIntegration())
    }
    public static func replaceInQueue(queue: ArrayList<?Element>, out: Element, inEl: Element) {
        let i: Int64 = queue.lastIndexOf(out)
        Validate.isTrue(i != -1)
        queue[i] = inEl
    }
    public static func isSpecial(el: Element): Bool {
        let namespace = el.tag().namespace()
        let name = el.normalName()
        return match (namespace) {
            case NamespaceHtml => StringUtil.inSorted(name, HtmlTreeBuilder.TagSearchSpecial())
            case Parser.NamespaceMathml => StringUtil.inSorted(name, HtmlTreeBuilder.TagSearchSpecialMath())
            case Parser.NamespaceSvg => StringUtil.inSorted(name, HtmlTreeBuilder.TagSvgHtmlIntegration())
            case _ => false}
    }
    public static func isSameFormattingElement(a: Element, b: Element): Bool {
        return (a.normalName() == b.normalName()) && (a.attributes() == b.attributes())
    }
}

package ksoup_cj

class Ksoup {
    private init() {}
    public static let INSTANCE = Ksoup()
    static func parse(html: String, baseUri!: String = ""): Document {
        return Parser.parse(html, baseUri: baseUri)
    }
    static func parse(html: String, parser!: Parser = Parser.htmlParser(), baseUri!: String = ""): Document {
        return parser.parseInput(html, baseUri)
    }
    static func parse(reader: Reader, parser!: Parser = Parser.htmlParser(), baseUri!: String = ""): Document {
        return parser.parseInput(reader, baseUri)
    }
    static func parseXml(xml: String, baseUri!: String = ""): Document {
        return Parser.xmlParser().parseInput(xml, baseUri)
    }
    static func parseBodyFragment(bodyHtml: String, baseUri!: String = ""): Document {
        return Parser.parseBodyFragment(bodyHtml, baseUri: baseUri)
    }
    static func clean(bodyHtml: String, safelist!: Safelist = Safelist.relaxed(), baseUri!: String = "", outputSettings!: ?OutputSettings = None): String {
        var uri = baseUri
        if (uri.isEmpty() && safelist.preserveRelativeLinks()) {
            uri = SharedConstants.DummyUri
        }
        let dirty: Document = parseBodyFragment(bodyHtml, baseUri: uri)
        let cleaner = Cleaner(safelist)
        let clean: Document = cleaner.clean(dirty)
        if (let Some(outputSettingsValue) <- outputSettings) {
            let outputSettings = outputSettingsValue
            clean.outputSettings(outputSettings)
        }
        return clean.body().html()
    }
    static func isValid(bodyHtml: String, safelist!: Safelist = Safelist.relaxed()): Bool {
        return Cleaner(safelist).isValidBodyHtml(bodyHtml)
    }
    static func parseMetaData(element: Element): MetaData {
        let el = if ((element is Document)) {
            element.headOrNull() ?? element
        } else {
            element
        }
        let title = el.selectFirst("title")?.text()
        return parseMetaDataInternal(element.baseUri(), title, { query => el.selectFirst(query) })
    }
    static func parseMetaData(html: String, baseUri!: String = "", interceptor!: ?((Element, MetaData) -> Unit) = None): MetaData {
        let head = if (let Some(doc) <- parse(html, baseUri: baseUri)) {
            doc.headOrNull() ?? doc
        }
        let title = head.selectFirst("title")?.text()
        return { it =>
            let _also_it = parseMetaDataInternal(baseUri, title, { query => head.selectFirst(query) })
            let _it = _also_it
            interceptor?.invoke(head, _it)
            return _also_it
        }()
    }
    static func parseMetaDataInternal(baseUri: String, title: ?String, selectFirst: (String) -> ?Element): MetaData {
        let ogTitle = selectFirst("meta[property=og:title]")?.attr("content")
        let ogSiteName = selectFirst("meta[property=og:site_name]")?.attr("content")
        let ogType = selectFirst("meta[property=og:type]")?.attr("content")
        let ogLocale = selectFirst("meta[property=og:locale]")?.attr("content")
        let ogDescription = selectFirst("meta[property=og:description]")?.attr("content")
        let ogImage = selectFirst("meta[property=og:image]")?.attr("content")
        let ogUrl = selectFirst("meta[property=og:url]")?.attr("content")
        let twitterTitle = selectFirst("meta[name=twitter:title]")?.attr("content")
        let twitterCard = selectFirst("meta[name=twitter:card]")?.attr("content")
        let twitterDescription = selectFirst("meta[name=twitter:description]")?.attr("content")
        let twitterImage = selectFirst("meta[name=twitter:image]")?.attr("content")
        let titleTag = selectFirst("meta[name=title]")?.attr("content")
        let descriptionTag = selectFirst("meta[name=description]")?.attr("content")
        let author = selectFirst("meta[name=author]")?.attr("content")
        let canonicalTag = selectFirst("link[rel=canonical]")?.attr("href")
        var faviconTag = selectFirst("link[rel~=icon]")?.attr("href")
        if (((faviconTag.isSome()) && !faviconTag.startsWith("http", true)) && !(baseUri.isEmpty())) {
            faviconTag = baseUri + faviconTag.toString()
        }
        var shortcutIcon = selectFirst("link[rel~=shortcut icon]")?.attr("href")
        if (((shortcutIcon.isSome()) && !shortcutIcon.startsWith("http", true)) && !(baseUri.isEmpty())) {
            shortcutIcon = baseUri + shortcutIcon.toString()
        }
        return MetaData(ogTitle, ogSiteName, ogType, ogLocale, ogDescription, ogImage, ogUrl, twitterCard, twitterTitle, twitterDescription, twitterImage, titleTag, descriptionTag, canonicalTag, title, author, faviconTag, shortcutIcon)
    }
}

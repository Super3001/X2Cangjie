package ksoup_cj

class MetaData <: ToString {
    let ogTitle: ?String
    let ogSiteName: ?String
    let ogDescription: ?String
    let ogImage: ?String
    let ogUrl: ?String
    let ogType: ?String
    let ogLocale: ?String
    let twitterCard: ?String
    let twitterTitle: ?String
    let twitterDescription: ?String
    let twitterImage: ?String
    let title: ?String
    let description: ?String
    let canonical: ?String
    let htmlTitle: ?String
    let author: ?String
    let favicon: ?String
    let shortcutIcon: ?String
    init(ogTitle!: ?String = None, ogSiteName!: ?String = None, ogDescription!: ?String = None, ogImage!: ?String = None, ogUrl!: ?String = None, ogType!: ?String = None, ogLocale!: ?String = None, twitterCard!: ?String = None, twitterTitle!: ?String = None, twitterDescription!: ?String = None, twitterImage!: ?String = None, title!: ?String = None, description!: ?String = None, canonical!: ?String = None, htmlTitle!: ?String = None, author!: ?String = None, favicon!: ?String = None, shortcutIcon!: ?String = None) {
        this.ogTitle = ogTitle
        this.ogSiteName = ogSiteName
        this.ogDescription = ogDescription
        this.ogImage = ogImage
        this.ogUrl = ogUrl
        this.ogType = ogType
        this.ogLocale = ogLocale
        this.twitterCard = twitterCard
        this.twitterTitle = twitterTitle
        this.twitterDescription = twitterDescription
        this.twitterImage = twitterImage
        this.title = title
        this.description = description
        this.canonical = canonical
        this.htmlTitle = htmlTitle
        this.author = author
        this.favicon = favicon
        this.shortcutIcon = shortcutIcon
    }
    public func toString(): String {
        return "MetaData(ogTitle=${this.ogTitle}, ogSiteName=${this.ogSiteName}, ogDescription=${this.ogDescription}, ogImage=${this.ogImage}, ogUrl=${this.ogUrl}, ogType=${this.ogType}, ogLocale=${this.ogLocale}, twitterCard=${this.twitterCard}, twitterTitle=${this.twitterTitle}, twitterDescription=${this.twitterDescription}, twitterImage=${this.twitterImage}, title=${this.title}, description=${this.description}, canonical=${this.canonical}, htmlTitle=${this.htmlTitle}, author=${this.author}, favicon=${this.favicon}, shortcutIcon=${this.shortcutIcon})"
    }
}

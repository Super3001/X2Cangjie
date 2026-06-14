package ksoup_cj

class SharedConstants {
    private init() {
        this.UserDataKey = "/ksoup.userdata"
        this.AttrRangeKey = "ksoup.attrs"
        this.RangeKey = "ksoup.start"
        this.EndRangeKey = "ksoup.end"
        this.XmlnsAttr = "ksoup.xmlns-"
        this.DEFAULT_CHAR_BUFFER_SIZE = 8192
        this.DefaultBufferSize = 8 * 1024
        this.FormSubmitTags = ["input", "keygen", "object", "select", "textarea"]
        this.DummyUri = "https://dummy.example/"
    }
    public static let INSTANCE = SharedConstants()
    let UserDataKey: String
    let AttrRangeKey: String
    let RangeKey: String
    let EndRangeKey: String
    let XmlnsAttr: String
    let DEFAULT_CHAR_BUFFER_SIZE: Int64
    let DefaultBufferSize: Int64
    let FormSubmitTags: Array<String>
    let DummyUri: String
}

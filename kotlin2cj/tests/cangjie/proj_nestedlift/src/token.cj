package proj_nestedlift

open class Token {}

class TokenComment <: Token {
    var data: String = ""
    public open func show(): String {
        return "token:" + data
    }
}

class Doctype <: Token {
    var name: String = ""
}

package ksoup_cj

abstract class QuietAppendable {
    public func append(csq: ?String): QuietAppendable
    public func append(c: Rune): QuietAppendable
    public func append(chars: Array<Rune>, offset: Int64, len: Int64): QuietAppendable
    public static func wrap(a: Appendable): QuietAppendable {
        return if ((a is StringBuilder)) {
            StringBuilderAppendable(a)
        } else {
            BaseAppendable(a)
        }
    }
}

class BaseAppendable <: QuietAppendable {
    let a: Appendable
    init(a: Appendable) {
        this.a = a
    }
    public open func quiet(action: Action): BaseAppendable {
        try {
            action.append()
        } catch (e: IOException) {
            throw SerializationException(e)
        }
        return this
    }
    public open override func append(csq: ?String): BaseAppendable {
        return quiet({ => a.append(csq) })
    }
    public open override func append(c: Rune): BaseAppendable {
        return quiet({ => a.append(c) })
    }
    public open override func append(chars: Array<Rune>, offset: Int64, len: Int64): QuietAppendable {
        return quiet({ => a.append(chars.concatToString(offset, offset + len)) })
    }
}

interface Action {
    func append(): Unit
}

class StringBuilderAppendable <: QuietAppendable & ToString {
    let sb: StringBuilder
    init(sb: StringBuilder) {
        this.sb = sb
    }
    public open override func append(csq: ?String): StringBuilderAppendable {
        sb.append(csq)
        return this
    }
    public open override func append(c: Rune): StringBuilderAppendable {
        sb.append(c)
        return this
    }
    public open override func append(chars: Array<Rune>, offset: Int64, len: Int64): QuietAppendable {
        sb.appendRange(chars, offset, offset + len)
        return this
    }
    public open override func toString(): String {
        return sb.toString()
    }
}

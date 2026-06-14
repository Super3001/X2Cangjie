package ksoup_cj

class TokenData <: ToString {
    var _value: ?String = None
    var builder: ?StringBuilder = None
    func set(str: String) {
        reset()
        _value = str
    }
    func append(str: String) {
        if (builder.isSome()) {
            builder.getOrThrow().append(str)
        } else if (_value.isSome()) {
            flipToBuilder()
            builder.getOrThrow().append(str)
        } else {
            _value = str
        }
    }
    func append(c: Rune) {
        if (builder.isSome()) {
            builder.getOrThrow().append(c)
        } else if (_value.isSome()) {
            flipToBuilder()
            builder.getOrThrow().append(c)
        } else {
            _value = c.toString()
        }
    }
    func appendCodePoint(codepoint: Int64) {
        if (builder.isSome()) {
            builder.getOrThrow().appendCodePoint(codepoint)
        } else if (_value.isSome()) {
            flipToBuilder()
            builder.getOrThrow().appendCodePoint(codepoint)
        } else {
            _value = Character.toChars(codepoint).concatToString()
        }
    }
    func flipToBuilder() {
        builder = StringUtil.borrowBuilder()
        builder.getOrThrow().append(_value)
        _value = None
    }
    func hasData(): Bool {
        return (builder.isSome()) || (_value.isSome())
    }
    func reset() {
        if (let Some(it) <- builder) {
            StringUtil.releaseBuilderVoid(it)
            builder = None
        }
        _value = None
    }
    func value(): String {
        if (let Some(it) <- builder) {
            _value = it.toString()
            StringUtil.releaseBuilder(it)
            builder = None
            return _value.getOrThrow()
        }
        return _value ?? ""
    }
    public override func toString(): String {
        return builder.toString() ?? (_value ?? "")
    }
}

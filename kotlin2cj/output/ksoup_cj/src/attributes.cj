package ksoup_cj

import std.collection.*

class Attributes <: Iterable & KCloneable & ToString {
    var _size = 0
    var keys: Array<?String> = arrayOfNulls(InitialCapacity)
    var vals = arrayOfNulls<Object>(InitialCapacity)
    func checkCapacity(minNewSize: Int64) {
        Validate.isTrue(minNewSize >= _size)
        let curCap = keys.size
        if (curCap >= minNewSize) {
            return
        }
        var newCap = if (curCap >= InitialCapacity) {
            _size * GrowthFactor
        } else {
            InitialCapacity
        }
        if (minNewSize > newCap) {
            newCap = minNewSize
        }
        keys = keys.copyOf(newCap)
        vals = vals.copyOf(newCap)
    }
    func indexOfKey(key: String): Int64 {
        for (i in 0.._size) {
            if (key == keys[i]) {
                return i
            }
        }
        return NotFound
    }
    func indexOfKeyIgnoreCase(key: String): Int64 {
        for (i in 0.._size) {
            if (key.equals(keys[i], true)) {
                return i
            }
        }
        return NotFound
    }
    func get(key: String): String {
        let i = indexOfKey(key)
        return if (i == NotFound) {
            EmptyString
        } else {
            checkNotNull(vals[i])
        }
    }
    func attribute(key: ?String): ?Attribute {
        let i = indexOfKey(key.getOrThrow())
        return if (i == NotFound) {
            None
        } else {
            Attribute(key, checkNotNull(vals[i]), this)
        }
    }
    func getIgnoreCase(key: String): String {
        let i = indexOfKeyIgnoreCase(key)
        return if (i == NotFound) {
            EmptyString
        } else {
            checkNotNull(vals[i])
        }
    }
    func add(key: String, value: ?String): Attributes {
        addObject(key, value)
        return this
    }
    func addObject(key: String, value: ?Object) {
        checkCapacity(_size + 1)
        keys[_size] = key
        vals[_size] = value
        _size += 1
    }
    func put(key: String, value: ?String): Attributes {
        let i = indexOfKey(key)
        if (i != NotFound) {
            vals[i] = value
        } else {
            addObject(key, value)
        }
        return this
    }
    func userData(): HashMap<String, Object> {
        let _userData: HashMap<String, Object>
        let i = indexOfKey(SharedConstants.UserDataKey)
        if (i == NotFound) {
            userData = HashMap()
            addObject(SharedConstants.UserDataKey, userData)
        } else {
            userData = (vals[i] as HashMap<String, Object>)
        }
        return userData
    }
    func hasUserData(): Bool {
        return hasKey(SharedConstants.UserDataKey)
    }
    func userData(key: String): ?Object {
        if (!hasUserData()) {
            return None
        }
        let _userData: HashMap<String, Object> = userData()
        return userData[key]
    }
    func userData(key: String, value: ?Object): Attributes {
        if ((value.isNone()) && !hasUserData()) {
            return this
        }
        let _userData = userData()
        if (let Some(valueValue) <- value) {
            let value = valueValue
            userData.put(key, value)
        } else {
            userData.remove(key)
        }
        return this
    }
    func putIgnoreCase(key: String, value: ?String) {
        let i = indexOfKeyIgnoreCase(key)
        if (i != NotFound) {
            vals[i] = value
            let old = keys[i]
            if ((old.isSome()) && (old != key)) {
                keys[i] = key
            }
        } else {
            addObject(key, value)
        }
    }
    func put(key: String, value: Bool): Attributes {
        if (value) {
            putIgnoreCase(key, None)
        } else {
            remove(key)
        }
        return this
    }
    func put(attribute: Attribute): Attributes {
        put(attribute.key, attribute.value)
        attribute.parent = this
        return this
    }
    func remove(index: Int64) {
        Validate.isFalse(index >= _size)
        let shifted = (_size - index) - 1
        if (shifted > 0) {
            keys.copyInto(keys, index, index + 1, (index + 1) + shifted)
            vals.copyInto(vals, index, index + 1, (index + 1) + shifted)
        }
        _size -= 1
        keys[_size] = None
        vals[_size] = None
    }
    func remove(key: String): Unit {
        let i = indexOfKey(key)
        if (i != NotFound) {
            remove(i)
        }
    }
    func removeIgnoreCase(key: String) {
        let i = indexOfKeyIgnoreCase(key)
        if (i != NotFound) {
            remove(i)
        }
    }
    func hasKey(key: String): Bool {
        return indexOfKey(key) != NotFound
    }
    func hasKeyIgnoreCase(key: String): Bool {
        return indexOfKeyIgnoreCase(key) != NotFound
    }
    func hasDeclaredValueForKey(key: String): Bool {
        let i = indexOfKey(key)
        return (i != NotFound) && (vals[i].isSome())
    }
    func hasDeclaredValueForKeyIgnoreCase(key: String): Bool {
        let i = indexOfKeyIgnoreCase(key)
        return (i != NotFound) && (vals[i].isSome())
    }
    func size(): Int64 {
        if (_size == 0) {
            return 0
        }
        var count = 0
        for (i in 0.._size) {
            if (!isInternalKey(keys[i])) {
                count += 1
            }
        }
        return count
    }
    func isEmpty(): Bool {
        return _size() == 0
    }
    func addAll(incoming: Attributes) {
        let incomingSize = incoming.size()
        if (incomingSize == 0) {
            return
        }
        checkCapacity(_size + incomingSize)
        let needsPut = _size != 0
        for (attr in incoming) {
            if (needsPut) {
                put(attr)
            } else {
                addObject(attr.key, attr.value)
            }
        }
    }
    func sourceRange(key: String): AttributeRange {
        if (!hasKey(key)) {
            return UntrackedAttr
        }
        let ranges: HashMap<String, AttributeRange> = getRanges() ?? return
        UntrackedAttr
        return ranges.get(key) ?? UntrackedAttr
    }
    func getRanges(): ?HashMap<String, AttributeRange> {
        return (userData(SharedConstants.AttrRangeKey) as ?HashMap<String, AttributeRange>)
    }
    func sourceRange(key: String, range: AttributeRange): Attributes {
        var ranges = getRanges()
        if (ranges.isNone()) {
            ranges = HashMap<String, AttributeRange>()
            userData(SharedConstants.AttrRangeKey, ranges)
        }
        ranges[key] = range
        return this
    }
    public override func iterator(): MutableIterator<Attribute> {
        return object
    }
    func asList(): ArrayList<Attribute> {
        let list: ArrayList<Attribute> = ArrayList([_size])
        for (i in 0.._size) {
            let key = keys[i]
            if (isInternalKey(key)) {
                continue
            }
            let attr = Attribute(key, (vals[i] as ?String), this)
            list.add(attr)
        }
        return collectArrayList(list)
    }
    func dataset(): Dataset {
        return Dataset(this)
    }
    func html(): String {
        let sb: StringBuilder = StringUtil.borrowBuilder()
        html(QuietAppendable.wrap(sb), OutputSettings())
        return StringUtil.releaseBuilder(sb)
    }
    func html(accum: QuietAppendable, out: OutputSettings) {
        let sz = _size
        for (i in 0..sz) {
            let key = keys[i]
            if (isInternalKey(key)) {
                continue
            }
            let validated = Attribute.getValidKey(key, out.syntax())
            if (let Some(validatedValue) <- validated) {
                let validated = validatedValue
                Attribute.htmlNoValidate(validated, (vals[i] as ?String), accum.append(r' '), out)
            }
        }
    }
    public override func toString(): String {
        return html()
    }
    public override func equals(other: ?Object): Bool {
        if (this == other) {
            return true
        }
        if ((other.isNone()) || (this != other)) {
            return false
        }
        let that = (other as Attributes)
        if (_size != that.size) {
            return false
        }
        for (i in 0.._size) {
            let key = keys[i]
            let thatI = that.indexOfKey(key)
            if ((thatI == NotFound) || (vals[i] != that.vals[thatI])) {
                return false
            }
        }
        return true
    }
    public override func hashCode(): Int64 {
        var result = _size
        result = (31 * result) + keys.hashCode()
        result = (31 * result) + vals.hashCode()
        return result
    }
    public override func clone(): Attributes {
        let attributes = Attributes()
        attributes.addAll(this)
        attributes.size = _size
        attributes.keys = keys.copyOf(_size)
        attributes.vals = vals.copyOf(_size)
        let i = indexOfKey(SharedConstants.UserDataKey)
        if (i != NotFound) {
            vals[i] = HashMap([(vals[i] as HashMap<?String, ?Object>)])
        }
        return attributes
    }
    func normalize() {
        for (i in 0.._size) {
            let key = keys[i]
            if (!isInternalKey(key)) {
                keys[i] = key.toAsciiLower()
            }
        }
    }
    func deduplicate(settings: ParseSettings): Int64 {
        if (_size == 0) {
            return 0
        }
        let preserve: Bool = settings.preserveAttributeCase()
        var dupes = 0
        for (i in 0.._size) {
            let keyI = keys[i]
            var j = i + 1
            while (j < _size) {
                if ((preserve && (keyI == keys[j])) || (!preserve && keyI.equals(keys[j], true))) {
                    dupes += 1
                    remove(j)
                    j -= 1
                }
                j += 1
            }
        }
        return dupes
    }
    func set(key: String, value: String): ?String {
        let dataKey = dataKey(key)
        let oldValue = if (attributes.hasKey(dataKey)) {
            attributes[dataKey]
        } else {
            None
        }
        attributes.put(dataKey, value)
        return oldValue
    }
    func get(key: String): ?String {
        let dataKey = "${dataPrefix}${key}"
        return if ((dataKey.toRuneArray().size > dataPrefix.toRuneArray().size) && attributes.hasKey(dataKey)) {
            attributes[dataKey]
        } else {
            None
        }
    }
    func remove(key: String) {
        attributes.remove("${dataPrefix}${key}")
    }
}

class Dataset {
    let attributes: Attributes
    init(attributes: Attributes) {
        this.attributes = attributes
    }
    let _size: Int64
}

main() {
    companion
}

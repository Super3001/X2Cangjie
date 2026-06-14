package ksoup_cj

import std.collection.*

open class Nodes<T> <: MutableList {
    let delegateList: ArrayList<T>
    init(delegateList!: ArrayList<T> = ArrayList()) {
        this.delegateList = delegateList
    }
    public open override func equals(other: ?Object): Bool {
        if (this == other) {
            return true
        }
        if (!(other is Nodes<Object>)) {
            return false
        }
        if (this.size != other.getOrThrow().size) {
            return false
        }
        for (i in (0..this.size)) {
            if (this[i] != other[i]) {
                return false
            }
        }
        return true
    }
    public open override func hashCode(): Int64 {
        return delegateList.hashCode()
    }
    // NOTE: inline reified function omitted — not supported by translator
}

package ksoup_cj

import std.collection.*

extend IntArray {
    func codePointsToString(): String {
        return if (!(this.isEmpty())) {
            buildString({ it =>
                for (it in this) {
                    appendCodePoint(it)
                }
            })
        } else {
            ""
        }
    }
}

extend ArrayList<E> {
    func removeRange(fromIndex: Int64, toIndex: Int64) {
        for (i in (toIndex - 1)..=fromIndex : -1) {
            this.remove(at: i)
        }
    }
}

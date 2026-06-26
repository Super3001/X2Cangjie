package proj_extensions

import std.collection.*
import std.convert.*

func __k2cjRuneSlice(input: String, start: Int64, end: Int64): String {
    let _r = input.toRuneArray()
    let _out = Array<Rune>(end - start, { _ => r'\u{0000}' })
    var _i = 0
    while (_i < end - start) {
        _out[_i] = _r[start + _i]
        _i++
    }
    String(_out)
}

extend Int64 {
    func isEven(): Bool {
        return (this % 2) == 0
    }
}
extend Int64 {
    func isOdd(): Bool {
        return (this % 2) != 0
    }
}
extend Int64 {
    func factorial(): Int64 {
        var result = 1
        var i = 1
        while (i <= this) {
            result *= i
            i += 1
        }
        return result
    }
}
extend String {
    func repeat(n: Int64): String {
        let sb = StringBuilder()
        var i = 0
        while (i < n) {
            sb.append(this)
            i += 1
        }
        return sb.toString()
    }
}
extend String {
    func countChar(target: String): Int64 {
        var count = 0
        var i = 0
        while (i < this.toRuneArray().size) {
            if (__k2cjRuneSlice(this, i, i + 1) == target) {
                count += 1
            }
            i += 1
        }
        return count
    }
}
extend ArrayList<Int64> {
    func computeAvg(): Int64 {
        if (this.size == 0) {
            return 0
        }
        var sum = 0
        for (n in this) {
            sum += n
        }
        return sum / this.size
    }
}

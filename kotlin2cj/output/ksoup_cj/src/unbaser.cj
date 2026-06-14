package ksoup_cj

import std.collection.*
import std.convert.*

class Unbaser <: ToString {
    let base: Int64
    init(base: Int64) {
        this.base = base
    }
    let selector: Int64 = if (base > 62) {
        95
    } else if (base > 54) {
        62
    } else if (base > 52) {
        54
    } else {
        52
    }
    let dict = { => collectArrayList(Unbaser.ALPHABET()[selector].iterator().enumerate().map({ _p => ({ index, c => (c, index) })(_p[0], _p[1]) }))?.toMap() }()
    func unbase(value: String): Int64 {
        return if (base >= 2 && base <= 36) {
            value.toIntOrNull(base) ?? 0
        } else {
            var returnVal = 0
            let valArray = ({ => let _r = value.toRuneArray(); String(Array<Rune>(_r.size, {j => _r[_r.size - 1 - j]})) })()
            for (i in (0..valArray.toRuneArray().size)) {
                let cipher = valArray.toRuneArray()[i]
                returnVal += Int64((Float64.parse(base).pow(i) * (dict?.get(cipher) ?? 0)))
            }
            returnVal
        }
    }
    static func ALPHABET(): HashMap<Int64, String> {
        return HashMap<Int64, String>([(52, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP"), (54, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQR"), (62, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"), (95, " !\"#\$%&\\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")])
    }
    public func toString(): String {
        return "Unbaser(base=${this.base})"
    }
}

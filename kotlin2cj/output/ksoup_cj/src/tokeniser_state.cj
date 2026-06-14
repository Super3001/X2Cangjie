package ksoup_cj

import std.deriving.*

@Derive[Hashable, Equatable]
enum TokeniserState <: ToString {
    | Data
    public func toString(): String {
    return match (this) {
                case Data => "Data"
}
    }
}

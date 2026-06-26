package target_1d

import std.convert.*
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

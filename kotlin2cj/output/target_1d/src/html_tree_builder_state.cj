package target_1d

import std.convert.*
import std.deriving.*

@Derive[Hashable, Equatable]
enum HtmlTreeBuilderState <: ToString {
    | Initial
    public func toString(): String {
    return match (this) {
                case Initial => "Initial"
}
    }
}

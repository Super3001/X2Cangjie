package target_1g

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

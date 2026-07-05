package target_1e

import std.deriving.*

@Derive[Hashable, Equatable]
enum LineEnding <: ToString {
    | Default | Lenient
    public func toString(): String {
    return match (this) {
                case Default => "Default"
            case Lenient => "Lenient"
}
    }
}

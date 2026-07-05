package target_1e

import std.deriving.*

@Derive[Hashable, Equatable]
enum ByteOrder <: ToString {
    | BIG_ENDIAN | LITTLE_ENDIAN
    public func toString(): String {
    return match (this) {
                case BIG_ENDIAN => "BIG_ENDIAN"
            case LITTLE_ENDIAN => "LITTLE_ENDIAN"
}
    }
}

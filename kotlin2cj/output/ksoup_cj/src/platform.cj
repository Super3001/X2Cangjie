package ksoup_cj

import std.deriving.*

@Derive[Hashable, Equatable]
enum PlatformType <: ToString {
    | ANDROID | ANDROID_NATIVE | JVM | IOS | LINUX | JS | MAC | WINDOWS | WASM_JS
    public func toString(): String {
    return match (this) {
                case ANDROID => "ANDROID"
            case ANDROID_NATIVE => "ANDROID_NATIVE"
            case JVM => "JVM"
            case IOS => "IOS"
            case LINUX => "LINUX"
            case JS => "JS"
            case MAC => "MAC"
            case WINDOWS => "WINDOWS"
            case WASM_JS => "WASM_JS"
}
    }
}

class Platform {
    private init() {}
    public static let INSTANCE = Platform()
    let current: PlatformType
}

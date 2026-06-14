package ksoup_cj

extend Platform {
    func isApple(): Bool {
        return (this.current == PlatformType.IOS) || (this.current == PlatformType.MAC)
    }
}

extend Platform {
    func isWindows(): Bool {
        return this.current == PlatformType.WINDOWS
    }
}

extend Platform {
    func isLinux(): Bool {
        return this.current == PlatformType.LINUX
    }
}

extend Platform {
    func isJvmOrAndroid(): Bool {
        return (this.current == PlatformType.JVM) || (this.current == PlatformType.ANDROID)
    }
}

extend Platform {
    func isJvm(): Bool {
        return this.current == PlatformType.JVM
    }
}

extend Platform {
    func isJsOrWasm(): Bool {
        return (this.current == PlatformType.JS) || (this.current == PlatformType.WASM_JS)
    }
}

extend Platform {
    func isWasmJs(): Bool {
        return this.current == PlatformType.WASM_JS
    }
}

package target_1g

import std.collection.*

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

class URLUtil {
    private init() {}
    public static let INSTANCE = URLUtil()
    static func resolve(base: String, relative: String): String {
        if (relative.isEmpty()) {
            return base
        }
        if (isAbsoluteUrl(relative)) {
            return relative
        }
        if (!isAbsoluteUrl(base)) {
            return ""
        }
        let baseUrl = parseUrl(base)
        if (relative.startsWith("//")) {
            return (baseUrl.scheme.toString() + ":") + relative
        }
        if (relative.startsWith("?")) {
            return "${baseUrl.scheme}:${baseUrl.schemeSeparator}${baseUrl.authority}${baseUrl.path}${relative}"
        }
        if (relative.startsWith("#")) {
            return "${baseUrl.scheme}:${baseUrl.schemeSeparator}${baseUrl.authority}${baseUrl.path}${baseUrl.query ?? ""}${relative}"
        }
        var resolvedPath = if (relative.startsWith("/")) {
            relative
        } else {
            let cleanedBasePath = stripQueryAndFragment(baseUrl.path)
            mergePaths(cleanedBasePath, relative)
        }
        let relQueryIndex = resolvedPath.indexOf("?")
        let relFragmentIndex = resolvedPath.indexOf("#")
        let queryOrFragmentIndex = if ((relQueryIndex != -1) && (relFragmentIndex != -1)) {
            (if (relQueryIndex < relFragmentIndex) { relQueryIndex } else { relFragmentIndex })
        } else if (relFragmentIndex != -1) {
            relFragmentIndex
        } else {
            relQueryIndex
        }
        let queryOrFragment = if (queryOrFragmentIndex != -1) {
            let result = __k2cjRuneSlice(resolvedPath, queryOrFragmentIndex, resolvedPath.toRuneArray().size)
            resolvedPath = __k2cjRuneSlice(resolvedPath, 0, queryOrFragmentIndex)
            result
        } else {
            None
        }
        let normalizedPath = if (let Some(it) <- normalizePath(resolvedPath, addRoot: !(baseUrl.authority.isEmpty()))) {
            if (let Some(queryOrFragmentValue) <- queryOrFragment) {
                let queryOrFragment = queryOrFragmentValue
                it + queryOrFragment
            } else {
                it
            }
        }
        let finalUrl = StringBuilder()
        finalUrl.append("${baseUrl.scheme}:${baseUrl.schemeSeparator}${baseUrl.authority}${normalizedPath}")
        return finalUrl.toString()
    }
    static func isAbsoluteUrl(url: String): Bool {
        return (url.toRuneArray().size > 2) && url.contains(":")
    }
    static func mergePaths(basePath: String, relativePath: String): String {
        let baseDir = if (basePath.endsWith("/")) {
            basePath
        } else {
            __k2cjRuneSlice(basePath, 0, basePath.lastIndexOf(r'/') + 1)
        }
        return baseDir.toString() + relativePath
    }
    static func normalizePath(path: String, addRoot!: Bool = true): String {
        let segments = collectArrayList(collectArrayList(path.split("/").iterator()))
        let result = ArrayList<String>()
        for ((index, segment) in segments.iterator().enumerate()) {
            if (segment.isEmpty() || (segment == ".")) {
                if (index == (segments.size - 1)) {
                    result.add("")
                }
            } else if (segment == "..") {
                if (!(result.isEmpty())) {
                    result.remove(at: result.size - 1)
                }
            } else {
                result.add(segment)
            }
        }
        return if (addRoot) {
            "/"
        } else {
            ""
        }.toString() + String.join(collectArray<String>(result.iterator().map({e => e.toString()})), delimiter: "/")
    }
    static func stripQueryAndFragment(path: String): String {
        let queryIndex = (path.indexOf("?") ?? -1)
        let fragmentIndex = (path.indexOf("#") ?? -1)
        return if (queryIndex != -1) {
            __k2cjRuneSlice(path, 0, queryIndex)
        } else if (fragmentIndex != -1) {
            __k2cjRuneSlice(path, 0, fragmentIndex)
        } else {
            path
        }
    }
    static func parseUrl(url: String): ParsedUrl {
        var remainingUrl = url
        let scheme: String
        let schemeSeparator: String
        let schemeEndIndex = (url.indexOf(":") ?? -1)
        if (schemeEndIndex != -1) {
            schemeSeparator = if ((url.indexOf("://") ?? -1) != -1) {
                "//"
            } else if ((url.indexOf(":/") ?? -1) != -1) {
                "/"
            } else {
                ""
            }
            scheme = __k2cjRuneSlice(url, 0, schemeEndIndex)
            remainingUrl = __k2cjRuneSlice(url, (schemeEndIndex + schemeSeparator.toRuneArray().size) + 1, url.toRuneArray().size)
        } else {
            scheme = "https"
            schemeSeparator = "//"
        }
        let authorityEndIndex = if (schemeSeparator != "/") {
            (((remainingUrl.indexOf("/") ?? -1).takeIf({ it => it != -1 }) ?? (remainingUrl.indexOf("?") ?? -1).takeIf({ it => it != -1 })) ?? (remainingUrl.indexOf("#") ?? -1).takeIf({ it => it != -1 })) ?? remainingUrl.toRuneArray().size
        } else {
            -1
        }
        let authority = if (authorityEndIndex != -1) {
            __k2cjRuneSlice(remainingUrl, 0, authorityEndIndex)
        } else {
            None
        }
        let pathAndMore = if (authorityEndIndex == -1) {
            remainingUrl
        } else {
            __k2cjRuneSlice(remainingUrl, authorityEndIndex, remainingUrl.toRuneArray().size)
        }
        let pathEndIndex = pathAndMore.indexOfAny([r'?', r'#']).takeIf({ it => it != -1 }) ?? pathAndMore.toRuneArray().size
        let path = __k2cjRuneSlice(pathAndMore, 0, pathEndIndex)
        let queryStartIndex = pathAndMore.indexOf(r'?').takeIf({ it => it != -1 }) ?? pathAndMore.toRuneArray().size
        let fragmentStartIndex = pathAndMore.indexOf(r'#').takeIf({ it => it != -1 }) ?? pathAndMore.toRuneArray().size
        let query = if (queryStartIndex != pathAndMore.toRuneArray().size) {
            __k2cjRuneSlice(pathAndMore, queryStartIndex, fragmentStartIndex)
        } else {
            None
        }
        let fragment = if (fragmentStartIndex != pathAndMore.toRuneArray().size) {
            __k2cjRuneSlice(pathAndMore, fragmentStartIndex, pathAndMore.toRuneArray().size)
        } else {
            None
        }
        return ParsedUrl(scheme, schemeSeparator, authority ?? "", path, query: query, fragment: fragment)
    }
}

class ParsedUrl {
    let scheme: String
    let schemeSeparator: String
    let authority: String
    let path: String
    let query: ?String
    let fragment: ?String
    init(scheme: String, schemeSeparator: String, authority: String, path: String, query!: ?String = None, fragment!: ?String = None) {
        this.scheme = scheme
        this.schemeSeparator = schemeSeparator
        this.authority = authority
        this.path = path
        this.query = query
        this.fragment = fragment
    }
}

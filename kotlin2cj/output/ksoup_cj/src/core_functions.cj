package ksoup_cj

func jsSupportedRegex(regex: String): Regex {
    return if (Platform.isJsOrWasm() && regex.contains("(?i)")) {
        Regex(regex.replace("(?i)", ""), RegexOption.IGNORE_CASE)
    } else {
        Regex(regex)
    }
}

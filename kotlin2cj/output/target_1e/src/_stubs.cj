package target_1e

// Kotlin `Long.toInt()` — our Int maps to Int64; identity for this subset's range checks.
extend Int64 {
    func toInt(): Int64 { return this }
}

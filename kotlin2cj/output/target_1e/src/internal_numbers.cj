package target_1e

extend Int64 {
    func toIntOrFail(name: String): Int64 {
        if (this >= Int64.Max) {
            failLongToIntConversion(this, name)
        }
        return toInt()
    }
}

func failLongToIntConversion(value: Int64, name: String): Nothing {
    throw IllegalArgumentException("Long value ${value} of ${name} doesn't fit into 32-bit integer")
}

package target_1g

func assert(condition: Bool, error!: ?String = None) {
    if (!condition) {
        throw Exception(error ?? "Assert error!")
    }
}

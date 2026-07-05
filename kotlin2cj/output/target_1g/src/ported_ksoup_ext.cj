package target_1g

extend Array<T> {
    func binarySearch(element: T): Int64 {
        var low = 0
        var high = this.size - 1
        while (low <= high) {
            let mid = (low + high).ushr(1)
            let midVal = get(mid)
            let cmp = compareValues(midVal, element)
            if (cmp < 0) {
                low = mid + 1
            } else if (cmp > 0) {
                high = mid - 1
            } else {
                return mid
            }
        }
        return -(low + 1)
    }
}

extend IntArray {
    func binarySearch(key: Int64): Int64 {
        var low = 0
        var high = this.size - 1
        while (low <= high) {
            let mid = (low + high) >> 1
            let midVal = this[mid]
            if (midVal < key) {
                low = mid + 1
            } else if (midVal > key) {
                high = mid - 1
            } else {
                return mid
            }
        }
        return -(low + 1)
    }
}

extend Array<T> {
    func binarySearchBy(comparison: (T) -> Int64): Int64 {
        var low = 0
        var high = size - 1
        while (low <= high) {
            let mid = (low + high).ushr(1)
            let midVal = get(mid)
            let cmp = comparison(midVal)
            if (cmp < 0) {
                low = mid + 1
            } else if (cmp > 0) {
                high = mid - 1
            } else {
                return mid
            }
        }
        return -(low + 1)
    }
}

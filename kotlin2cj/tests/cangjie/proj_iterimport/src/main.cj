package proj_iterimport

import std.collection.*
import std.convert.*

main() {
    let result = ArrayList<Int64>()
    let iter = CountIterator(5)
    while (iter.hasNext()) {
        result.add(iter.next())
    }
    println(String.join(collectArray<String>(result.iterator().map({e => e.toString()})), delimiter: " "))
}

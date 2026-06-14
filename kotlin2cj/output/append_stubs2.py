#!/usr/bin/env python3
STUBS = """
open class NodeList {
    init(size: Int64) {}
    var size: Int64 = 0
    func modCount(): Int64 { return 0 }
}
let EmptyNodeList = NodeList(0)
open class LinkedHashSet<T> {
    init() {}
    func add(e: T): Bool { return true }
    func addAll(c: Any): Bool { return true }
    func isEmpty(): Bool { return true }
    var size: Int64 = 0
}
func linkedSetOf<T>(): LinkedHashSet<T> { return LinkedHashSet() }
class Dataset {
    init(attrs: Any) {}
}
"""
with open("/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src/_stubs.cj", "a") as f:
    f.write(STUBS)
print("Appended NodeList/LinkedHashSet/Dataset stubs")

package target_1g

import std.collection.*

class IdentityHashMap<K, V> <: MutableMap {
    let delegate: HashMap<IdentityWrapper<K>, V> = HashMap<IdentityWrapper<K>, V>()
    let size: Int64
    public override func containsKey(key: K): Bool {
        return delegate.contains(IdentityWrapper(key))
    }
    public override func containsValue(value: V): Bool {
        return delegate.containsValue(value)
    }
    public override func get(key: K): ?V {
        return delegate[IdentityWrapper(key)]
    }
    public override func isEmpty(): Bool {
        return delegate.isEmpty()
    }
    let entries: HashSet<MutableMap.MutableEntry<K, V>>
    let keys: HashSet<K>
    let values: MutableCollection<V>
    public override func clear() {
        delegate.clear()
    }
    public override func put(key: K, value: V): ?V {
        return delegate.put(IdentityWrapper(key), value)
    }
    public override func putAll(from: HashMap<K, V>) {
        for (__tuple in from) {
            let (k, v) = __tuple
            this[k] = v
        }
    }
    public override func remove(key: K): ?V {
        return delegate.remove(IdentityWrapper(key))
    }
}

class IdentityWrapper<T> {
    let value: T
    init(value: T) {
        this.value = value
    }
    public override func hashCode(): Int64 {
        return value.hashCode()
    }
    public override func equals(other: ?Object): Bool {
        return (other is IdentityWrapper<Object>) && (other.getOrThrow().value == value)
    }
}

class IdentityEntry<K, V> <: MutableMap.MutableEntry {
    let original: MutableMap.MutableEntry<IdentityWrapper<K>, V>
    init(original: MutableMap.MutableEntry<IdentityWrapper<K>, V>) {
        this.original = original
    }
    let key: K
    let value: V
    public override func setValue(newValue: V): V {
        return original.setValue(newValue)
    }
}

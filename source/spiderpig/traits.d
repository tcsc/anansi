module spiderpig.traits;

import std.range, std.typecons;
import spiderpig.container;

final struct VecS {}
final struct ListS {}

template StorageIndex(T) { }

template StorageIndex(T : VecS) {
    alias StorageIndex = size_t;
}

template StorageIndex(Selector : ListS) {
    alias StorageIndex = void*;
}

// ----------------------------------------------------------------------------
//
// ----------------------------------------------------------------------------

template Storage(Selector, ValueType) {}

template Storage(Selector : VecS, ValueType) {
  alias Storage = Array!ValueType;
}

template Storage(Selector : ListS, ValueType) {
  alias Storage = List!ValueType;
}

// ----------------------------------------------------------------------------
//
// ----------------------------------------------------------------------------

auto push(Storage, ValueType)(ref Storage store, ValueType value) {
    auto rval = store.insertBack(value);
    return tuple(rval, true);
}

void erase(Storage, IndexType)(ref Storage store, IndexType index) {
    store.erase(index);
}

auto range(Storage, ValueType)(ref Storage store) {

}

auto range(Storage : Array!ValueType, ValueType)(ref Storage store) {
    return iota(0, store.length);
}

auto range(Storage : List!ValueType, ValueType)(ref Storage store) {
    struct Range {
        alias Node = List!(ValueType).Node;

        this(Node* front, Node* back) { _front = front; _back = back; }

        @property bool empty() const { return _front is null; }
        @property void* front() { return cast(void*) _front; }
        void popFront() { 
            if (_front is _back) 
                _front = _back = null;
            else
                _front = _front.nextNode;
        }

    private:
        Node* _front;
        Node* _back;
    }

    static assert(isInputRange!Range);

    return Range(store.frontNode, store.backNode);
}

// ----------------------------------------------------------------------------


ref inout(ValueType) get_value(Storage, ValueType, IndexType)(
    ref inout(Storage) store, IndexType index) {
    static assert(False, "get_value not defined for this type");
}

ref inout(ValueType) get_value(Storage : Array!ValueType, ValueType, IndexType)(
    ref inout(Storage) store, IndexType index) {
    return store[index];
}

ref inout(ValueType) get_value(Storage : List!ValueType, ValueType, IndexType)(
    ref inout(Storage) store, IndexType index) {
    auto node = cast(inout(List!(ValueType).Node)*) index;
    return node.value;
}

// ----------------------------------------------------------------------------
// 
// ----------------------------------------------------------------------------

final struct DirectedS {};
final struct UndirectedS {};
final struct BidirectionalS {};

// ----------------------------------------------------------------------------
// 
// ----------------------------------------------------------------------------

final static struct NoProperty {};

template isNone(T) {
  enum isNone = false;
}

template isNone(T: NoProperty) {
  enum isNone = true;
}

template isNotNone(T) { 
  enum isNotNone = !(isNone!T);
}
module spiderpig.traits;

import std.range, std.traits, std.typecons;
import spiderpig.container;

//final struct VecS {}

final struct VecS {
    alias IndexType = size_t;
    enum IndexesAreStable = false;

    static struct Store(ValueType) {
        auto push(ValueType value) {
            auto rval = _store.insertBack(value);
            return PushResult!(typeof(rval))(rval, true);
        }

        void erase(IndexType index) {
            _store.erase(index);
        }

        auto indexRange() {
            return iota(0, _store.length);
        }

        ref inout(ValueType) get_value(IndexType index) inout {
            return _store[index];
        }

        @property auto dup() {
            return Store(_store.dup);
        }

        alias _store this;
        Array!ValueType _store;
    }
}

final struct ListS {
    alias IndexType = void*;
    enum IndexesAreStable = true;

    static struct Store(ValueType) {
        auto push(ValueType value) {
            auto rval = _store.insertBack(value);
            return PushResult!(typeof(rval))(rval, true);
        }

        void erase(IndexType index) { 
            auto node = cast(List!(ValueType).Node*) index;
            _store.remove(node); 
        }

        auto indexRange() {
            static struct IndexRange {
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

            static assert(isInputRange!IndexRange);
            static assert(is(ElementType!IndexRange == void*));

            return IndexRange(_store.frontNode, _store.backNode);
        }

        ref inout(ValueType) get_value(IndexType index) inout {
            auto node = cast(inout(List!(ValueType).Node)*) index;
            return node.value;
        }

        @property auto dup() {
            return Store(_store.dup);
        } 

        alias _store this;

        List!ValueType _store;
    }
}

//template StorageIndex(T) { 
//    static assert(false, 
//                  "Index type not defined for selector " ~ 
//                  fullyQualifiedName!T);    
//}

//template StorageIndex(T : VecS) {
//    alias StorageIndex = size_t;
//}

//template StorageIndex(Selector : ListS) {
//    alias StorageIndex = void*;
//}

// ----------------------------------------------------------------------------
// Storage definitions
// ----------------------------------------------------------------------------

//template Storage(Selector, ValueType) {
//    static assert(false, 
//                  "Storage type not defined for selector " ~ 
//                  fullyQualifiedName!Selector);
//}

//template Storage(Selector : VecS, ValueType) {
//    alias Storage = Array!ValueType;
//}

//template Storage(Selector : ListS, ValueType) {
//    alias Storage = List!ValueType;
//}

//struct Store(Selector, ValueType) {
//    static assert(false, 
//                  "Store type not defined for selector " ~ 
//                  fullyQualifiedName!Selector);    
//}

//struct Store(Selector : VecS, ValueType) {
//    alias IndexType = size_t;
//    enum IndexesAreStable = false;

//    auto push(ValueType value) {
//        auto rval = _store.insertBack(value);
//        return PushResult!(typeof(rval))(rval, true);
//    }

//    void erase(IndexType index) {
//        _store.erase(index);
//    }

//    auto indexRange() {
//        return iota(0, _store.length);
//    }

//    ref inout(ValueType) get_value(IndexType index) inout {
//        return _store[index];
//    }

//    @property auto dup() {
//        return Store(_store.dup);
//    }

//    alias _store this;

//    Array!ValueType _store;
//}

//struct Store(Selector : ListS, ValueType) {
//    alias IndexType = void*;
//    enum IndexesAreStable = true;

//    auto push(ValueType value) {
//        auto rval = _store.insertBack(value);
//        return PushResult!(typeof(rval))(rval, true);
//    }

//    void erase(IndexType index) { 
//        auto node = cast(List!(ValueType).Node*) index;
//        _store.remove(node); 
//    }

//    auto indexRange() {
//        static struct IndexRange {
//            alias Node = List!(ValueType).Node;

//            this(Node* front, Node* back) { _front = front; _back = back; }

//            @property bool empty() const { return _front is null; }
//            @property void* front() { return cast(void*) _front; }
//            void popFront() { 
//                if (_front is _back) 
//                    _front = _back = null;
//                else
//                    _front = _front.nextNode;
//            }

//        private:
//            Node* _front;
//            Node* _back;
//        }

//        static assert(isInputRange!IndexRange);
//        static assert(is(ElementType!IndexRange == void*));

//        return IndexRange(_store.frontNode, _store.backNode);
//    }

//    ref inout(ValueType) get_value(IndexType index) inout {
//        auto node = cast(inout(List!(ValueType).Node)*) index;
//        return node.value;
//    }

//    @property auto dup() {
//        return Store(_store.dup);
//    } 

//    List!ValueType _store;

//    alias _store this;
//}

// ----------------------------------------------------------------------------
// Operations on a (possibly custom) storage type
// ----------------------------------------------------------------------------

struct PushResult(IndexType) {
    IndexType index;
    bool addedNew;
}

//auto push(Storage, ValueType)(ref Storage store, ValueType value) {
//    auto rval = store.insertBack(value);
//    return PushResult!(typeof(rval))(rval, true);
//}

//void erase(Storage, IndexType)(ref Storage store, IndexType index) {
//    store.erase(index);
//}

//auto range(Storage)(ref Storage store) {
//    return store[];
//}

//auto indexRange(Storage, ValueType)(ref Storage store) {
//    static assert(false, "No implementation of indexRange for type: " ~ 
//                         getFullyQualifiedName!Storage);
//}

//auto indexRange(Storage : Array!ValueType, ValueType)(ref Storage store) {
//    return iota(0, store.length);
//}

//auto indexRange(Storage : List!ValueType, ValueType)(ref Storage store) {
//    struct IndexRange {
//        alias Node = List!(ValueType).Node;

//        this(Node* front, Node* back) { _front = front; _back = back; }

//        @property bool empty() const { return _front is null; }
//        @property void* front() { return cast(void*) _front; }
//        void popFront() { 
//            if (_front is _back) 
//                _front = _back = null;
//            else
//                _front = _front.nextNode;
//        }

//    private:
//        Node* _front;
//        Node* _back;
//    }

//    static assert(isInputRange!IndexRange);
//    static assert(is(ElementType!IndexRange == void*));

//    return IndexRange(store.frontNode, store.backNode);
//}

// ----------------------------------------------------------------------------


ref inout(ValueType) get_value(Storage, ValueType, IndexType)(
    ref inout(Storage) store, IndexType index) {
    static assert(false, 
                  "get_value not defined for storage type: " ~ 
                  getFullyQualifiedName!Storage);
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
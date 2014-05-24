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

        IndexType rewriteIndex(IndexType removedIndex, IndexType target) {
            if (target > removedIndex) {
                return target - 1;
            }
            else {
                return target;
            }
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

        void eraseFrontOfRange(List!(ValueType).Range range) 
        in {
            assert (!range.empty, "Range must not be empty.");
        }
        body {
            _store.remove(range.frontNode);
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

struct PushResult(IndexType) {
    IndexType index;
    bool addedNew;
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
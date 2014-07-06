module anansi.traits;

import std.range, std.traits, std.typecons;
import anansi.container;

// ----------------------------------------------------------------------------
// Graph concepts
// ----------------------------------------------------------------------------

template isGraph (G) {
    enum bool isGraph = is(typeof(
    (inout int = 0) {
        G g = G.init;         // We can create a graph
        G.VertexDescriptor v; // T defines a vertex descriptor type
        G.EdgeDescriptor e;   // T defines an eddge descriptor type
    }));
}

template isIncidenceGraph (G) {
    enum bool isIncidenceGraph = isGraph!G && is(typeof(
    (inout int = 0) {
        G g;
        G.VertexDescriptor v;
        size_t x = g.outDegree(v);                // Can query vertex degree
        foreach(e; g.outEdges(v)) {               // Can enumerate vertex edges
            G.EdgeDescriptor e2 = e;              // Edge values are EdgeDescriptors
            G.VertexDescriptor src = g.source(e); // Can query edge source
            G.VertexDescriptor dst = g.target(e); // Can query edge target
        }
    }));   
}

// ----------------------------------------------------------------------------
// Property map 
// ----------------------------------------------------------------------------

template isReadablePropertyMap (T, IndexT, ValueT) {
    enum bool isReadablePropertyMap = is(typeof(
    (ref T t, IndexT idx) {
        ValueT v = t[idx]; // can query
    }));
}

template isPropertyMap (T, IndexT, ValueT) {
    enum bool isPropertyMap = is(typeof(
    (ref T t, IndexT idx) {
        ValueT v = t[idx]; // can query
        t[idx] = v;        // can set
    }));
}

// ----------------------------------------------------------------------------
// Queue concept
// ----------------------------------------------------------------------------

/**
 * 
 */
template isQueue(T, ValueT) {
    enum bool isQueue = is(typeof(
    (ref T t) {
        bool e = t.empty;
        ValueT v = t.front;
        t.push(v); 
        t.pop();
    }));
}

// ----------------------------------------------------------------------------
// Container specifiers
// ----------------------------------------------------------------------------

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

        auto indexRange() const {
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

        auto indexRange() const {
            static struct IndexRange {
                alias Node = List!(ValueType).Node;

                this(const(Node)* front, const(Node)* back) { 
                    _front = front; 
                    _back = back; 
                }

                @property bool empty() const { return _front is null; }
                @property void* front() const { return cast(void*) _front; }
                void popFront() { 
                    if (_front is _back) 
                        _front = _back = null;
                    else
                        _front = _front.nextNode;
                }

            private:
                const(Node)* _front;
                const(Node)* _back;
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
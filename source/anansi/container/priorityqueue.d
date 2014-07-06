/**
 * A priority queue implementation for use with the anasi graph library.
 * License: Boost Software License 1.0.
 */
 module anansi.container.priorityqueue;

 import std.exception, std.functional, std.math, std.range, std.traits;

/**
 * A priority queue implementation. Items with the highest priority (as defined
 * by the supplied predicate) come off the queue first. You can change the 
 * order of the queue by supplying a custom predicate, or overriding opCmp 
 * on the type being queued.
 */
struct PriorityQueue(T, alias Predicate = "a > b") {
    this(Stuff)(Stuff stuff) if (isInputRange!Stuff && 
                                 isImplicitlyConvertible!(ElementType!Stuff, T)) {
        foreach(s; stuff)
            push(s);
    }

    public void push(T value) {
        _payload ~= move(value);
        bubbleUp(_payload.length-1);
    }

    @property size_t length() const {
        return _payload.length;
    }

    @property bool empty() const {
        return _payload.length == 0;
    }

    /**
     * Fetches a reference to the highest-priority element in the queue.
     */
    public ref inout(T) front() inout
    in {
        assert (_payload.length > 0, "The queue may not be empty.");
    } 
    body {
        return _payload[0];
    }

    /**
     * Removes the highest-priority item from the queue. The queue must not 
     * be empty.
     */
    public void pop() 
    in {
        assert (_payload.length > 0, "The queue may not be empty.");
    }
    body {
        _payload[0] = move(_payload[$-1]);
        _payload = _payload[0 .. $-1];
        if (_payload.length > 1)
            siftDown(0);
    }

    public void updateIf(alias FindPredicate,
                         alias UpdateOperation)() {
        alias isItem = unaryFun!FindPredicate;
        alias update = unaryFun!UpdateOperation;

        foreach(i, ref t; _payload) {
            if (isItem(t)) {
                update(t);
                reHeap(i);
            }
        }
    }

    public void updateIf(FindPredicate, UpdateOperation)(
        FindPredicate isItem, UpdateOperation update) {

        foreach(i, ref t; _payload) {
            if (isItem(t)) {
                update(t);
                reHeap(i);
                break;
            }
        }
    }

    /**
     * Repairs the heap, assuming that the value at the given index
     * has changed.
     */
    private void reHeap(size_t index) {
        if (!bubbleUp(index))
            siftDown(index);
    }

    /**
     * Recursively enforces the heap property of the items in the 
     * payload array, from the bottom up.
     */
    private bool bubbleUp(size_t index) {
        bool result = false;
        if( index > 0) {
            size_t parentIndex = ((index-1) / 2);
            if (greaterThan(_payload[index], _payload[parentIndex])) {
                swap(_payload[parentIndex], _payload[index]);
                bubbleUp(parentIndex);
                result = true;
            }
        }
        return result;
    }

    /**
     * Recursively enforces the heap property of the items in the payload 
     * array, from the top down.
     */
    private void siftDown(size_t index) {
        immutable size_t leftChild = (index * 2) + 1;
        immutable size_t rightChild = leftChild + 1;

        immutable size_t nChildren = 
            sgn(cast(int)_payload.length - cast(int)rightChild) + 1;

        switch(nChildren) {
            case 0:
                // no children, we're already at the leaf
                break;

            case 1:
                // one child, by definition the left one.
                if (greaterThan(_payload[leftChild], _payload[index])) {
                    swap(_payload[index], _payload[leftChild]);
                }
                break;

            case 2:
                // two children, examine the larger child and push the values
                // down the tree 
                immutable size_t target = 
                    greaterThan(_payload[leftChild], _payload[rightChild]) ? 
                        leftChild : rightChild;
                if (greaterThan(_payload[target], _payload[index])) {
                    swap(_payload[index], _payload[target]);
                    siftDown(target);
                }
                break;

            default:
                enforce(false, "This should never happen.");
                break;
        }
    }

    alias greaterThan = binaryFun!Predicate;

    /**
     * The items in the queue, stored as implicit tree that satisfies the heap 
     * property.
     */
    private T[] _payload;
}

// ----------------------------------------------------------------------------
//
// ----------------------------------------------------------------------------

version (unittest) {
    import std.conv, std.stdio;
}

unittest {
    writeln("PriorityQueue: Default construction should yield an empty queue.");
    PriorityQueue!int q;
    assert (q.empty, "Default-constructed queue must be empty.");
    assert (q.length == 0, "Default-constructed queue must have 0 elements.");
}

unittest {
    writeln("PriorityQueue: Construction from a range yields a valid queue.");
    auto q = PriorityQueue!int([1, 3, 5, 7, 9, 2, 4, 6, 8, 10]);
    assert (q.length == 10, 
        "Expected a queue of length 10, got " ~ to!string(q.length));
    auto expected = 10;
    while (!q.empty) {
        assert (q.front == expected, 
            "Expected a value of " ~ to!string(expected) ~ 
            ", got " ~ to!string(q.front));
        --expected;
        q.pop();
    }
}

unittest {
    writeln("PriorityQueue: Copying creates an independant queue.");
    auto q = PriorityQueue!int([1, 3, 5, 7, 9, 2, 4, 6, 8, 10]);
    auto p = q;
    q.push(11);
    assert(q.length == 11 && p.length == 10);

    p.pop();
    assert(q.length == 11 && p.length == 9);
}

unittest {
    writeln("PriorityQueue: Pushing element results in a valid queue.");
    PriorityQueue!int q;

    foreach(n; [1, 3, 5, 7, 9, 2, 4, 6, 8, 10]) {
        q.push(n);
    }

    auto expected = 10;
    while (!q.empty) {
        assert (q.front == expected, 
            "Expected a value of " ~ to!string(expected) ~ 
            ", got " ~ to!string(q.front));
        --expected;
        q.pop();
    }
}

unittest {
    writeln("PriorityQueue: Custom predicates can change the order of the queue.");
    auto q = PriorityQueue!(int, "a < b")([1, 3, 5, 7, 9, 2, 4, 6, 8, 10]);
    assert (q.length == 10, 
        "Expected a queue of length 10, got " ~ to!string(q.length));
    
    foreach (expected; 1 .. 11) {
        assert (q.front == expected, 
            "Expected a value of " ~ to!string(expected) ~ 
            ", got " ~ to!string(q.front));
        q.pop();
    }
}

unittest {
    writeln("PriorityQueue: Increasing a key value  with a static function reorders the queue.");
    auto q = PriorityQueue!(int)([1, 3, 5, 7, 9, 2, 4, 6, 8, 10]);
    q.updateIf!("a == 7", (ref int x) => x = 42)();

    foreach (expected; [42, 10, 9, 8, 6, 5, 4, 3, 2, 1]) {
        assert (q.front == expected, 
            "Expected a value of " ~ to!string(expected) ~ 
            ", got " ~ to!string(q.front));
        q.pop();
    }
}

unittest {
    writeln("PriorityQueue: Decreasing a key value with a static function reorders the queue.");
    auto q = PriorityQueue!(int)([1, 3, 5, 7, 9, 2, 4, 6, 8, 10]);
    q.updateIf!("a == 7", (ref int x) => x = 0)();

    foreach (expected; [10, 9, 8, 6, 5, 4, 3, 2, 1, 0]) {
        assert (q.front == expected, 
            "Expected a value of " ~ to!string(expected) ~ 
            ", got " ~ to!string(q.front));
        q.pop();
    }
}

unittest {
    writeln("PriorityQueue: Increasing a key value  with a static function reorders the queue.");
    auto q = PriorityQueue!(int)([1, 3, 5, 7, 9, 2, 4, 6, 8, 10]);
    const int y = 7;
    const int z = 42;
    q.updateIf((int x) => x == y, (ref int x) => x = z);

    foreach (expected; [42, 10, 9, 8, 6, 5, 4, 3, 2, 1]) {
        assert (q.front == expected, 
            "Expected a value of " ~ to!string(expected) ~ 
            ", got " ~ to!string(q.front));
        q.pop();
    }
}

unittest {
    writeln("PriorityQueue: Decreasing a key value with a static function reorders the queue.");
    auto q = PriorityQueue!(int)([1, 3, 5, 7, 9, 2, 4, 6, 8, 10]);
    const int y = 7;
    const int z = 0;
    q.updateIf((int x) => x == y, (ref int x) => x = z);

    foreach (expected; [10, 9, 8, 6, 5, 4, 3, 2, 1, 0]) {
        assert (q.front == expected, 
            "Expected a value of " ~ to!string(expected) ~ 
            ", got " ~ to!string(q.front));
        q.pop();
    }
}

unittest {
    writeln("PriorityQueue: Not changing a key value leaves the queue alone.");
    auto q = PriorityQueue!(int)([1, 3, 5, 7, 9, 2, 4, 6, 8, 10]);
    q.updateIf!("a == 7", (ref int x) => x = x)();

    foreach (expected; [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]) {
        assert (q.front == expected, 
            "Expected a value of " ~ to!string(expected) ~ 
            ", got " ~ to!string(q.front));
        q.pop();
    }
}
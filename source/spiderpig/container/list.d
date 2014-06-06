module spiderpig.container.list;

import std.algorithm, std.conv, std.range, std.stdio, std.traits;

/**
 * A doubley-linked list with a deliberately leaky abstraction. This container 
 * is explicitly for use with the spiderpig graph classes. 
 */
public struct List(T) {
private:
    this(size_t s, Node* f, Node* b) {
        _size = s;
        _front = f;
        _back = b;
    }

public:
    this(this) {
        auto chain = copyChain(_front, _back);
        _front = chain[0];
        _back = chain[1];
    }

public:
    /**
     * The internal data storage object 
     */
    static struct Node {
        protected this(T v, Node* p, Node* n) {
            value = v;
            p = prev;
            n = next; 
        }

        public @property inout(Node*) nextNode() inout {
            return next;
        }

        protected Node* prev;
        protected Node* next;
        public T value;

        public @property ref inout(T) valueRef() inout { 
            return value; 
        }
    }

    static struct ConstRange {
        public this(const(Node)* front, const(Node)* back) {
            _front = front;
            _back = back;
        }

        @property bool empty() const { 
            return (_front is null);
        }

        @property ref const(T) front() const 
        in {
            assert (_front !is null);
        }
        body {
            return (_front.value);
        }

        void popFront() 
        in {
            assert (_front !is null);
        }
        body {
            if (_front is _back)
                _front = _back = null;
            else
                _front = _front.next;
        }

        @property ConstRange save() { return this; }

        public @property const(Node)* frontNode() { 
            return _front; 
        }

    private:
        const(Node)* _front;
        const(Node)* _back;
    }

    static struct Range {
        public this(Node* front, Node* back) {
            _front = front;
            _back = back;
        }

        @property bool empty() const {
            return (_front is null);
        }

        @property ref T front() 
        in {
            assert (_front !is null);
        }
        body {
            return _front.value;
        }

        void popFront() 
        in {
            assert (_front !is null);
        }
        body {
            if (_front is _back)
                _front = _back = null;
            else
                _front = _front.next;
        }

        @property Range save() { return this; }

        public @property Node* frontNode() { return _front; }

    private:
        Node* _front;
        Node* _back;
    }

    invariant() {
        assert (_size >= 0, "Size must remain positive.");
    }

    this(Stuff)(Stuff stuff) if(isInputRange!Stuff &&
                                isImplicitlyConvertible!(ElementType!Range, T)) {
        foreach(s; stuff)
            insertBack(s);
    }

    Range opSlice() { return Range(_front, _back); }
    ConstRange opSlice() const { return ConstRange(_front, _back); }

    Node* insertBack(T value) 
    out(result) {
        assert (result !is null);
    }
    body {
        auto newNode = new Node(value, null, null);
        if (empty) {
            _front = _back = newNode;
        }
        else {
            newNode.prev = _back;
            _back.next = newNode;
            _back = newNode;
        }

        _size += 1;
        return newNode;
    }

    void remove(Node* node)
    in {
        assert (node !is null);
        assert (_size > 0);
    }
    out {
        assert (_size >= 0);
    }
    body {
        if (node is _front && node is _back) {
            _front = _back = null;
        }
        else if (node is _front) {
            _front = _front.next;
            _front.prev = null;
        }
        else if (node is _back) {
            _back = _back.prev;
            _back.next = null;
        }
        else {
            node.next.prev = node.prev;
            node.prev.next = node.next;
        }
        --_size;
    }

    ref inout(T) front() inout 
    in {
        assert (_front !is null);
    }
    body {
        return _front.value;
    }

    @property inout(Node*) frontNode() inout { return _front; }

    ref inout(T) back() inout
    in {
        assert (_back !is null);
    }
    body {
        return _back.value;
    }

    @property inout(Node*) backNode() inout { return _back; }

    @property size_t length() const {
        return _size;
    }

    @property bool empty() const {
        return _back is null;
    }

    @property List dup() {
        auto newChain = copyChain(_front, _back);

        return List(_size, newChain[0], newChain[1]);
    }

private:
    static auto copyChain(Node* front, Node* back) {
        Node* newFront = null;
        Node* newBack = null;

        if (front !is null) {
            newFront = newBack = new Node(front.value, null, null);
            for(auto n = front.next; n != null; n = n.next) {
                auto newNode = new Node(n.value, newBack, null);
                newBack.next = newNode;
                newBack = newNode;
            }
        }

        return tuple(newFront, newBack);
    } 

private:
    Node* _front;
    Node* _back;
    size_t _size;
}

unittest {
    writeln("List: default construction.");
    List!int l;
    assert (l.length == 0);
}

unittest {
    writeln("List: construct from a Range.");
    auto data = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    auto list = List!int(data); 
    assert (list.length == data.length, 
    "Bad length value, expected: " ~ to!string(data.length) ~
    ", got: " ~ to!string(list.length));

    foreach(x; zip(data, list[])) {
        assert(x[0] == x[1], 
            "Bad list value, expected: " ~ to!string(x[0]) ~
            ", got: " ~ to!string(x[1]));
    }
}

unittest {
    writeln("List: empty range correctly marked as empty.");
    List!int l;
    assert(l[].empty, "An empty range should return empty == true");
}

unittest {
    writeln("List: remove only element in list.");
    List!char l;
    auto pn = l.insertBack('a');
    l.remove(pn);

    assert (l.length == 0, 
        "Length must be 0 after removing the only element.");

    size_t count;
    foreach(c; l[]) 
    ++count;

    assert(count == 0, 
        "Iterting over an empty list should never invoke loop body.");
}

unittest {
    writeln("List: remove first element in list.");
    List!int l;
    auto n0 = l.insertBack(0); 
    auto n1 = l.insertBack(1);
    auto n2 = l.insertBack(2);

    l.remove(n0);

    assert (l.length == 2);

    foreach(x; zip([1, 2], l[])) {
        assert(x[0] == x[1], 
            "Bad list value, expected: " ~ to!string(x[0]) ~
            ", got: " ~ to!string(x[1]));
    } 
}

unittest {
    writeln("List: remove last element in list.");
    List!int l;
    auto n0 = l.insertBack(0); 
    auto n1 = l.insertBack(1);
    auto n2 = l.insertBack(2);

    l.remove(n2);

    assert (l.length == 2);

    foreach(x; zip([0, 1], l[])) {
        assert(x[0] == x[1], 
            "Bad list value, expected: " ~ to!string(x[0]) ~
            ", got: " ~ to!string(x[1]));
    } 
}

unittest {
    writeln("List: remove middle element in list.");
    List!int l;
    auto n0 = l.insertBack(0); 
    auto n1 = l.insertBack(1);
    auto n2 = l.insertBack(2);

    l.remove(n1);

    assert (l.length == 2);

    foreach(x; zip([0, 2], l[])) {
    assert(x[0] == x[1], 
        "Bad list value, expected: " ~ to!string(x[0]) ~
        ", got: " ~ to!string(x[1]));
    }

    assert (l.front() == 0);
    assert (l.back() == 2);
}

unittest {
    writeln("List: remove all-but-one element in a list.");
    List!int l;
    auto n0 = l.insertBack(0); 
    auto n1 = l.insertBack(1);
    auto n2 = l.insertBack(2);

    l.remove(n1);
    l.remove(n2);

    assert (l.length == 1);

    foreach(x; zip([0], l[])) {
        assert(x[0] == x[1], 
            "Bad list value, expected: " ~ to!string(x[0]) ~
            ", got: " ~ to!string(x[1]));
    } 
}

unittest {
    writeln("List: remove all elements in a list.");
    List!int l;
    auto n0 = l.insertBack(0); 
    auto n1 = l.insertBack(1);
    auto n2 = l.insertBack(2);

    l.remove(n1);
    l.remove(n2);
    l.remove(n0);

    assert (l.length == 0);
    size_t count = 0;
    foreach(_; l[]) {
        ++count;
    } 

    assert (count == 0, 
        "iterating over an empty range should never hit the loop body.");
}
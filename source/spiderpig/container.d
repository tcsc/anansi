module spiderpig.container;

import std.algorithm, std.conv, std.range, std.stdio, std.traits;

version(unittest) {
    import std.range;
}

package struct Array(T) {
private:
    this(size_t size, T[] payload) {
        _size = size;
        _payload = payload;
    }

public:
    this(U)(U[] stuff) if (isImplicitlyConvertible!(U, T)) {
        foreach(s; stuff)
            insertBack(s);
    }

    this(Stuff)(Stuff stuff) if (isInputRange!Stuff && 
                                 isImplicitlyConvertible!(ElementType!Stuff, T) &&
                                 !is(Stuff == T[])) {
        foreach(s; stuff) 
            insertBack(s);
    } 

    this(this) {
        _payload = _payload[0 .. _size].dup;
    }

    invariant() { 
        assert(_size >= 0); 
        assert(_payload.length >= _size);
    }

public:
    size_t insertBack(T value) {
        ensureSpace(_size+1);
        _payload[_size] = move(value);
        return _size++;
    }

    size_t insert(T value, size_t index) 
    in {
        assert(index <= _size);
    }
    body {
        ensureSpace(_size+1);
        moveAll(_payload[index .. $-1], _payload[index + 1 .. $]);
        _payload[index] = move(value);
        _size += 1;
        return index;
    }

    void erase(size_t index) {
        erase(index, 1);
    }

    /**
     * Erases a contiguous range of items from the array.
     */
    void erase(size_t index, size_t count) 
    in {
        assert(index < _size, "Index must be smaller than Array.length.");
        assert((index + count) <= _size, "Range must not overflow array.");
    }
    body {
        auto leftovers = moveAll(_payload[index + count .. $], _payload[index .. $]);
        foreach(ref t; leftovers) { t = T.init; }

        _size -= count;
        if (_size < (_payload.length / 2))
            _payload.length = _size;
    }

    void reserve(size_t n) {     
        if (_payload.length < n)
            _payload.length = n;
    }

    Range opSlice() {
        return Range(_payload, _size);
    }

public:
    static struct Range {
        this(T[] data, size_t size) {
            _data = data;
            _size = size;
        }

        @property bool empty() const {
            return _index == _size;
        }

        @property size_t length() const {
            return _size;
        } 

        @property ref T front() 
        in {
            assert (_index < _size);
        }
        body {
            return _data[_index];
        }

        void popFront() 
        in {
            assert (_index < _size);
        }
        body {
            ++_index;
        }

    private:
        size_t _index;
        size_t _size;
        T[] _data;
    }

public:
    /**
     * Provides [] sytax for the array.
     */
    ref inout(T) opIndex(size_t index) inout
    in {
        assert(index < _size, "Index must be less than Array.length.");
    }
    body {
        return _payload[index];
    }

    /**
     * Returns the number of elements currently stored in the array.
     */
    @property size_t length() const {
        return _size;
    }

    /**
     * Returns the number of items the array could store, given its 
     * current buffer allocation.
     */
    @property size_t capacity() const {
        return _payload.length;
    }

    @property Array dup() {
        return Array(_size, _payload[0 .. _size].dup);
    }

private:
    /**
     * Ensures that there is storage space a minimum number of elements in
     * the array, possibly over-allocating for efficiency's sake.
     */
    void ensureSpace(size_t n) {
        if (_payload.length < n) {
            size_t newSize = 1 + ((_payload.length * 3) / 2);
            auto newPayload = new T[newSize];
            moveAll(_payload, newPayload[0 .. _size]);            
            _payload = newPayload;
        }
    }

private:
    size_t _size;
    T[] _payload;
}

unittest {
  writeln("Array: empty construction.");
  Array!string s;
  assert(s.length == 0);
  assert(s.capacity >= 0);
}

unittest {
  writeln("Array: construction from a Range.");
  auto data = ["alpha", "beta", "delta", "gamma", "epsilon"];
  auto s = Array!string(data);

  assert(s.length == data.length);
  for(auto i = 0; i < data.length; ++i)
    assert(s[i] == data[i]);
}

unittest {
  writeln("Array: insertion into empty Array");
  Array!string a;
  auto i = a.insert("hi", 0);
  assert (a.length == 1, "Incorrect length after insertion.");
  assert (a[0] == "hi", "Incorrect value at insertion point.");
  assert (i == 0, "Incorrect insertion point index returned.");
}

unittest {
  writeln("Array: insertion at the end of an Array.");
  auto data = ["alpha", "beta", "delta", "gamma", "epsilon"];
  auto a = Array!string(data);
  auto i = a.insert("o hai", a.length);
  assert (i == data.length, "Incorrect insertion point index returned.");

  assert (a.length == (data.length+1), "Incorrect length after insertion.");  

  for(auto n = 0; n < data.length; ++n) 
    assert (a[n] == data[n]);

  assert (a[data.length] == "o hai", 
          "Incorrect value at insertion point.");
}

unittest {
  writeln("Array: erasing a single item in the middle of the list.");
  auto a = Array!int(iota(0, 100, 1));
  assert(a.length == 100);
  assert(a[7] == 7);

  a.erase(7);    
  assert(a.length == 99);
  foreach(i; 0 .. 7)
    assert(a[i] == i);

  foreach(i; 7 .. 99)
    assert(a[i] == (i+1));
}

version(unittest) {
  /**
   * A test struct that tracks the execution of its destructor, for use in
   * testing.
   */
  struct DtorTestValue {
    static int dtorCount = 0;
    int n;
    ~this() {
      if (n != 0) {
        ++dtorCount;                
      }
    }
  }
}


unittest {
  writeln("Array: erasing the only item in an Array.");
  auto a = Array!DtorTestValue();    
  a.insertBack(DtorTestValue(1));
  DtorTestValue.dtorCount = 0;
  a.erase(0);   
  assert(a.length == 0);    
  assert (DtorTestValue.dtorCount == 1, 
          "bad dtor count: " ~ to!string(DtorTestValue.dtorCount));
}

unittest {
  writeln("Array: erasing the first item in an Array.");
  Array!DtorTestValue a;
  a.reserve(100);
  foreach(n; 0 .. 100)
    a.insertBack(DtorTestValue(n+1));

  DtorTestValue.dtorCount = 0;
  a.erase(0);    
  assert(a.length == 99);

  assert (DtorTestValue.dtorCount == 1, 
          "bad dtor count: " ~ to!string(DtorTestValue.dtorCount));

  foreach(i; 0 .. 99) {
    assert(a[i].n == (i+2), 
          "Invalid post-erase value: expected " ~ to!string(i+2) ~ 
          ", got: " ~ to!string(a[i].n));
  }
}

unittest {
  writeln("Array: erasing the last item in an array.");
  Array!DtorTestValue a;
  a.reserve(100);
  foreach(n; 0 .. 100)
    a.insertBack(DtorTestValue(n+1));

  DtorTestValue.dtorCount = 0;
  a.erase(99);    
  assert(a.length == 99);

  assert (DtorTestValue.dtorCount == 1, 
          "bad dtor count: " ~ to!string(DtorTestValue.dtorCount));

  foreach(i; 0 .. 99)
    assert(a[i].n == i+1);
}

unittest {
  writeln("Array: erasing a single, essentially random, item.");
  Array!DtorTestValue a;
  a.reserve(100);
  foreach(n; 0 .. 100)
    a.insertBack(DtorTestValue(n+1));

  DtorTestValue.dtorCount = 0;
  a.erase(7);    
  assert(a.length == 99);

  assert (DtorTestValue.dtorCount == 1, 
          "bad dtor count: " ~ to!string(DtorTestValue.dtorCount));

  foreach(i; 0 .. 7)
    assert(a[i].n == (i+1));

  foreach(i; 7 .. 99)
    assert(a[i].n == (i+2));
}

unittest {
  writeln("Array: erasing a range of items from the array.");
  auto a = Array!int(iota(0, 100, 1));
  a.erase(25, 50);
  assert (a.length == 50, 
    "Post-erasure length is wrong: " ~ to!string(a.length)); 

  foreach(i; 0 .. 25)
    assert(a[i] == i, "Bad pre-erased-range value");

  foreach(i; 25 .. 50)
    assert(a[i] == (i+50), "Bad post-erased-range value. " ~
                           "Expected " ~ to!string(i+25) ~ 
                           ", got " ~ to!string(a[i]));
}

unittest {
  writeln("Array: erasing the entire array");
  auto a = Array!int(iota(0, 100, 1));
  assert(a.length == 100);
  a.erase(0, 100);

  assert(a.length == 0, 
    "Array should be empty after erasing it all.");

  assert(a.capacity == 0, 
    "Internal capacity should be 0 after erasing all items.");
}

// ----------------------------------------------------------------------------
// List
// ----------------------------------------------------------------------------

/**
 * A doubley-linked list with a deliberately leaky abstraction, for easy use 
 * with the spiderpig graph types.
 */
package struct List(T) {
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
    static struct Node {
    protected:
        this(T v, Node* p, Node* n) {
            value = v;
            p = prev;
            n = next; 
        }

        package @property Node* nextNode() {
            return next;
        }

    protected:
        Node* prev;
        Node* next;

    public:
        T value;
    }

    static struct Range {
    public:
        this(Node* front, Node* back) {
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

    @property Node* frontNode() { return _front; }

    ref inout(T) back() inout
    in {
        assert (_back !is null);
    }
    body {
        return _back.value;
    }

    @property Node* backNode() { return _back; }

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
import std.algorithm, std.conv, std.range, std.stdio, std.traits;

version(unittest) {
  import std.range;
}

package struct Array(T) {
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

    @disable this(this);

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
    // empty construction
    Array!string s;
    assert(s.length == 0);
}

unittest {
    // construction from an array
    auto data = ["alpha", "beta", "delta", "gamma", "epsilon"];
    auto s = Array!string(data);

    assert(s.length == data.length);
    for(auto i = 0; i < data.length; ++i)
        assert(s[i] == data[i]);
}

unittest {
    // erasing a single item - make sure that all elements have moved up the line.
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
    // erasing the only item in an array 
    auto a = Array!DtorTestValue();    
    a.insertBack(DtorTestValue(1));
    DtorTestValue.dtorCount = 0;
    a.erase(0);   
    assert(a.length == 0);    
    assert (DtorTestValue.dtorCount == 1, 
            "bad dtor count: " ~ to!string(DtorTestValue.dtorCount));
}

unittest {
    // erasing the first item in an array    
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
    // erasing the last item in an array
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
    // erasing a single essentially random item
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
    // erasing a range of items from the array
    auto a = Array!int(iota(0, 100, 1));
    a.erase(25, 50);
    assert (a.length == 50, "Post-erasure length is wrong: " ~ to!string(a.length)); 

    foreach(i; 0 .. 25)
        assert(a[i] == i, "Bad pre-erased-range value");

    foreach(i; 25 .. 50)
        assert(a[i] == (i+50), "Bad post-erased-range value. " ~
                               "Expected " ~ to!string(i+25) ~ 
                               ", got " ~ to!string(a[i]));
}

unittest {
    // erasing the entire array
    auto a = Array!int(iota(0, 100, 1));
    assert(a.length == 100);
    a.erase(0, 100);
    assert(a.length == 0, "Array should be empty after erasing it all.");
    assert(a.capacity == 0, "Internal capacity should be 0 after erasing all items.");
}

// ----------------------------------------------------------------------------
// 
// ----------------------------------------------------------------------------

package struct List(T) {
  static struct Node {
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
      return (_front !is null);
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

  @disable this(this);

  invariant() {
    assert (_size >= 0, "Size must remain positive.");
  }

  this(Stuff)(Stuff stuff) if(isInputRange!Stuff &&
                              isImplicitlyConvertible!(ElementType!Range, T)) {
    foreach(s; stuff)
      insertBack(s);
  }

  Range opSlice() { return Range(_front, _back); }

  Node* insertBack(T value) {
    auto newNode = new Node(null, null, value);
    if (empty) {
      _front = _back = newNode;
    }
    else {
      newNode.prev = _back;
      _front.next = newNode;
      _back = newNode;
    }

    _size += 1;
    return newNode;
  }

  @property size_t length() const {
    return _size;
  }

  @property bool empty() const {
    return _back is null;
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
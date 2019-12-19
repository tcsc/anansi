module anansi.container.array;

import std.algorithm, std.conv, std.range, std.stdio, std.traits;

version(unittest) {
    import std.range;
}

public struct Array(T) {
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

    void eraseFrontOfRange(RangeT)(RangeT r) 
        if (is(RangeT == Range!T) || is(RangeT == Range!(const T)))
    in {
        assert (!r.empty, "Range must not be empty.");
        assert (r._data is _payload);
    }
    body {
        erase(r._index, 1);
    }

    void reserve(size_t n) {     
        if (_payload.length < n)
            _payload.length = n;
    }

    auto opSlice() {
        return Range!(T)(_payload, _size);
    }

    auto opSlice() const {
        return Range!(const T)(_payload, _size);
    }

public:
    static struct Range(ElementT) {
        this(ElementT[] data, size_t size) {
            _index = 0;
            _data = data;
            _size = size;
        }

        @property bool empty() const {
            return _index == _size;
        }

        @property size_t length() const {
            return _size;
        } 

        @property ref ElementT front() 
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
        ElementT[] _data;
    }

    alias ConstRange = Range!(const T);

    /**
     * Provides [] sytax for the array.
     */
    public ref inout(T) opIndex(size_t index) inout
    in {
        assert(index < _size, "Index must be less than Array.length.");
    }
    body {
        return _payload[index];
    }

    /**
     * Returns the number of elements currently stored in the array.
     */
    public @property size_t length() const {
        return _size;
    }

    /**
     * Returns the number of items the array could store, given its 
     * current buffer allocation.
     */
    public @property size_t capacity() const {
        return _payload.length;
    }

    public @property Array dup() {
        return Array(_size, _payload[0 .. _size].dup);
    }

    /**
     * Ensures that there is storage space a minimum number of elements in
     * the array, possibly over-allocating for efficiency's sake.
     */
    private void ensureSpace(size_t n) {
        if (_payload.length < n) {
            size_t newSize = 1 + ((_payload.length * 3) / 2);
            auto newPayload = new T[newSize];
            moveAll(_payload, newPayload[0 .. _size]);            
            _payload = newPayload;
        }
    }

    private size_t _size;
    private T[] _payload;
}

unittest {
  writeln("Array: empty construction yields a valid Array.");
  Array!string s;
  assert(s.length == 0);
  assert(s.capacity >= 0);
}

unittest {
  writeln("Array: construction from a Range yields a valid Array.");
  auto data = ["alpha", "beta", "delta", "gamma", "epsilon"];
  auto s = Array!string(data);

  assert(s.length == data.length);
  for(auto i = 0; i < data.length; ++i)
    assert(s[i] == data[i]);
}

unittest {
  writeln("Array: insertion into empty Array yields a valid 1-element array.");
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
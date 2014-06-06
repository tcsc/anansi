module spiderpig.container.set;

import std.algorithm, std.conv, std.range, std.stdio, std.traits;

/**
 * 
 */
struct Set (T) {
    public this(Stuff)(Stuff stuff) 
        if (isInputRange!Stuff && 
            isImplicitlyConvertible!(ElementType!Stuff, T)) {
        foreach(s; stuff) 
            insert(s);
    } 

    public this(this) {
        _payload = _payload.dup;
    }

    @property size_t length() const {
        return _payload.length;
    }

    /**
     * Inserts a new value into the set.
     * Params:
     *   value = The value to insert into the set.
     *
     * Returns:
     *   Returns true if the value was inserted, or false if the value 
     *   already existed in the set.
     */
    public bool insert(T value) {
        int n = _payload[value]++;
        return (n == 0); 
    }

    /**
     * Inserts a range of elements into the set.
     *
     * Params:
     *   stuff = The range of items to insert into the set. 
     */
    public void insert(Stuff)(Stuff stuff)
        if (isInputRange!Stuff && 
            isImplicitlyConvertible!(ElementType!Stuff, T)) {
        foreach (s; stuff) 
            insert(s);
    }

    public bool contains(T value) const {
        auto p = (value in _payload);
        return (p !is null);
    }

    public int opApply(int delegate(ref T) dg) {
        int rval = 0;
        auto values = _payload.keys;
        for(int i = 0; (i < values.length) && (rval != 0); ++i)
            rval = dg(values[i]);
        return rval;
    }

    private int[T] _payload;
}

unittest {
    writeln("Set: Construction from a range.");
}

unittest {
    writeln("Set: Unique values are added.");
    Set!int s;
    foreach(n; 0 .. 5) {
        assert (s.insert(n), "Inserting a unique item should return true.");
    }

    assert (s.length == 5, "Expected length of 5, got: " ~to!string(s.length));
    foreach(n; 0 .. 5) {
        assert (s.contains(n), "Expected value " ~ to!string(n) ~ " missing.");
    }
}

unittest {
    writeln("Set: Duplicate values are not added.");
    Set!int s;
    assert (s.insert(1), "Expected insert to return true.");
    assert (!s.insert(1), "Expected duplicate insert to return false");
    assert (s.length == 1, "Expected length of 1, got " ~ to!string(s.length));
}
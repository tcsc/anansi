module anansi.container.stack;

import std.range, std.traits;

/**
 * Implements a 
 */
struct Stack(T) {
    public this(Stuff)(Stuff stuff) 
        if (isInputRange!Stuff && 
            isImplicitlyConvertible!(ElementType!Stuff, T)) {
        _payload = array(stuff);
    } 

    this(this) {
        _payload = _payload.dup;
    }

    void push(T value) {
        _payload ~= value;
    }

    void pop() 
    in {
        assert (_payload.length > 0, "Stack must not be empty to pop");
    }
    body {
        _payload = _payload[0 .. $-1];
        _payload.assumeSafeAppend();
    }

    @property ref inout(T) front() inout 
    in { 
        assert (_payload.length > 0, "Stack must not be empty to read front");
    }
    body {
        return _payload[$-1];
    }

    @property bool empty() const {
        return _payload.empty;
    }

    @property size_t length() const {
        return _payload.length;
    }

    private T[] _payload;
}

version (unittest) {
    import std.conv, std.stdio;
}

unittest {
    writeln("Stack: Default construction must yield an empty stack.");
    auto s = Stack!int();
    assert(s.empty, "A default-constructed stack should be empty");
    assert(s.length == 0, "A default-constructed stack should have a length of 0");
}

unittest {
    writeln("Stack: Construction from a range should yield a non-empty stack.");
    auto s = Stack!int([1, 2, 3, 4, 5, 6, 7, 8, 9]);
    assert (!s.empty, "Range-constructed stack should not be empty");
    assert (s.length == 9, "Range-constructed stack should have length 9.");
}

unittest {
    writeln("Stack: Enumerating a stack should yield items in reverse order.");
    auto s = Stack!int([1, 2, 3, 4, 5, 6, 7, 8, 9]);
    int expected = 9;
    while (!s.empty) {
        assert (s.front == expected, 
            "Expected " ~ to!string(expected) ~ 
            ", got " ~ to!string(s.front));
        s.pop();
        expected--;
    }
}

unittest {
    writeln("Stack: Adding an item to a stack should increase its length.");
    auto s = Stack!int();
    s.push(42);
    assert (!s.empty, "Stack should not be empty after push.");
    assert (s.length == 1, "Stack should not be empty after push.");
}

unittest {
    writeln("Stack: Popping an item from a stack should decrease its length.");
    auto s = Stack!int([1, 2, 3, 4, 5]);
    auto n = s.length;
    s.pop();
    assert (s.length == (n-1), "Stack length should be reduced by 1 after a pop.");

}
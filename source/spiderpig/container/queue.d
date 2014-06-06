module spiderpig.container.queue;
import std.algorithm, std.conv;

/**
 *
 */
struct FifoQueue(T) {
    invariant () {
        assert (_length <= _buffer.length, "Length must always be smaller than capacity.");
        assert (_length >= (_buffer.length / 2));
    }

    @property bool empty() const {
        return _length == 0;
    }

    public void push(T value) {
        if (_length == _buffer.length ) {
            realloc(1 + ((_buffer.length * 3) / 2));
        }
        _tail = (_tail + 1) % _buffer.length;
        _buffer[_tail] = value;
        _length++;
    }

    public void pop()
    in {
        assert (!empty);
    }
    body {
        _buffer[_head] = T.init;
        _head = (_head + 1) % _buffer.length; // [0, 1] 2, 1, 0
        _length = _length - 1;                // [0, 1] 2, 1, 0
        auto threshold = _buffer.length / 2;
        if (_length < threshold) {
            realloc(_length);
        }
    }

    private void realloc(size_t n) {
        auto newbuffer = new T[n];
        if( _length > 0 ) {
            if( _head == _tail) {
                newbuffer[0] = move(_buffer[_head]);
            }
            else if( _head < _tail ) {
                moveAll(_buffer[_head .. _tail+1], newbuffer[0 .. _length]);
            }
            else {
                auto trailingItems = _buffer.length - _head;
                moveAll(_buffer[_head .. $], newbuffer[]);
                moveAll(_buffer[0 .. _tail+1], newbuffer[trailingItems .. $]);
            }
            _head = 0;
            _tail = (_length - 1);
        }
        _buffer = newbuffer;
    } 

    public @property ref inout(T) front() inout
    in {
        assert (!empty);
    }
    body {
        return _buffer[_head];
    }

    public @property size_t length() const {
        return _length;
    }

    public @property size_t capacity() const  {
        return _buffer.length;
    }

    private T[] _buffer;
    private size_t _length;
    private size_t _head = 0;
    private size_t _tail = 0;
}

version (unittest) {
    import std.stdio;
}

unittest {
    writeln("FifoQueue: simple add & remove");
    auto q = FifoQueue!int();
    foreach(n; 1 .. 11) {
        q.push(n);
        assert (q.length == n, 
            "(push) Expected length " ~ to!string(n + 1) ~ 
            ", got " ~ to!string(q.length));
    }

    foreach(n; 1 .. 11) {
        assert (q.front == n, 
            "(pop) Expected front value " ~ to!string(n) ~ 
            ", got " ~ to!string(q.front));

        q.pop();
    }
}

unittest {
    writeln("FifoQueue: Staggered add & remove");
    auto q = FifoQueue!int();

    q.push(1);
    q.push(2);
    assert(q.length == 2, "Expected length == 2");
    assert(q.front == 1, "Expected front == 1");
    
    q.pop();
    assert(q.front == 2, "Expected front == 2");

    q.push(3);
    q.push(4);
    assert(q.length == 3, "Expected length == 3");
    assert(q.front == 2, "Expected front == 2");

    q.pop();
    assert(q.length == 2, "Expected length == 2");
    assert(q.front == 3, "Expected front == 3");

    q.push(5);
    q.push(6);
    q.push(7);

    assert(q.length == 5, "Expected length == 5");
    assert(q.front == 3, "Expected front == 3");

    q.pop();
    q.pop();

    assert(q.length == 3, "Expected length == 3");
    assert(q.front == 5, "Expected front == 5");

    q.push(8);
    q.push(9);
    q.push(10);

    assert(q.length == 6, "Expected length == 6");
    assert(q.front == 5, "Expected front == 5");
   
    q.pop();
    q.push(11);
    q.push(12);

    assert(q.length == 7, "Expected length == 7");
    assert(q.front == 6, "Expected front == 6");

    int x = 6; size_t l = q.length;
    while (!q.empty) {
        assert (x == q.front);
        assert (l == q.length);
        q.pop();
        x++;
        l--;
    }
}
import std.traits;
import container;

final struct ArrayS { }
final struct ListS { }

template isSelector(T) {
    static if (is(T == ArrayS) || is(T == ListS))
        enum isSelector = true;
    else
        enum isSelector = false;
}

final struct DirectedS { }
final struct UndirectedS { }
final struct BidirectionalS { }

template isDirectionality(T) {
    enum isDirectionality = (is(T == DirectedS) || 
                             is(T == UndirectedS) || 
                             is(T == BidirectionalS));
}


// ----------------------------------------------------------------------------
// 
// ----------------------------------------------------------------------------

package template ContainerType(S, ValueType) if (isSelector!S) 
{
    static if (is(S : ArrayS))
        alias ContainerType = Array!ValueType;
    else static if (is(S : ListS))
        alias ContainerType = DList!ValueType;
}

// ----------------------------------------------------------------------------
// 
// ----------------------------------------------------------------------------

template isGraph(GraphT) {
    static if(__traits(hasMember, GraphT, "addVertex") &&
              __traits(hasMember, GraphT, "addEdge") && 
              __traits(hasMember, GraphT, "vertexCount")) {
        enum isGraph = true;
    }
    else {
        enum isGraph = false;
    }
}

// ----------------------------------------------------------------------------
// 
// ----------------------------------------------------------------------------

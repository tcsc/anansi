module spiderpig.adjacencylist;

import std.conv, std.range, std.stdio,
       std.traits,
       std.typecons,
       std.typetuple;
import spiderpig.container, spiderpig.traits;

struct AdjacencyList (VertexStorage = VecS,
                      EdgeStorage = VecS,
                      Directionality = DirectedS,
                      VertexProperty = NoProperty,
                      EdgeProperty = NoProperty)
{
public:
    alias VertexDescriptor = StorageIndex!(VertexStorage);
    alias EdgeDescriptor = Tuple!(VertexDescriptor, "src", 
                                  StorageIndex!EdgeStorage, "index");
    enum IsBidirectional = is(Directionality == BidirectionalS);

private:
    struct Edge {
        VertexDescriptor dst;
        static if (!is(EdgeProperty == NoProperty)) {
            EdgeProperty  _property;
        }
    }

    struct Vertex {
    public:
        static if (isNotNone!VertexProperty) {
            this(VertexProperty p) { _property = p; }
        }

        this(this) {
            _outEdges = _outEdges.dup;
            static if (IsBidirectional) {
                _inEdges = _inEdges.dup;
            }
        }


    private:
        Storage!(EdgeStorage, Edge) _outEdges;

        static if (IsBidirectional) {
            Storage!(EdgeStorage, EdgeDescriptor) _inEdges;
        }

        static if (isNotNone!VertexProperty) {
            private:
                VertexProperty _property;

            public:
                @property ref inout(VertexProperty) property() inout {
                    return _property;
                }
        }
    }

    Storage!(VertexStorage, Vertex) _vertices;

public:
    static if (isNone!VertexProperty) {
        VertexDescriptor addVertex() {
            return _vertices.push(Vertex())[0];
        }
    }
    else {
        VertexDescriptor addVertex(VertexProperty property) {
            return _vertices.push(Vertex(property))[0];
        }
    }

    @property vertexCount() const {
        return _vertices.length;
    }

    /**
     * Returns a forward range that yields the descriptors for each vertex in 
     * the graph. The order of the vertices is undefined.
     */
    @property auto vertices() {
        return _vertices.range();
    }

    static if (!isNone!VertexProperty) {
        ref inout(VertexProperty) opIndex(VertexDescriptor v) inout {
            return _vertices.get_value(v).property;
        }
    }
}

unittest {
    writeln("AdjacencyList: Adding a vertex with no property.");
    foreach(VertexStorage; TypeTuple!(VecS, ListS)) {
        foreach(EdgeStorage; TypeTuple!(VecS, ListS)) {
            foreach(Directionality; TypeTuple!(DirectedS, UndirectedS, BidirectionalS)) {
                AdjacencyList!(VertexStorage, EdgeStorage, Directionality) g;
                auto v1 = g.addVertex();
                auto v2 = g.addVertex();
                auto v3 = g.addVertex();

                assert (g.vertexCount == 3,
                        "Bad vertex count. Exepected 3, got " ~ 
                        to!string(g.vertexCount));

                foreach(x; zip(g.vertices(), [v1, v2, v3][])) {
                    assert (x[0] == x[1], "Mismatched vertex descriptors");
                }
            }
        }
    }
}

unittest {
    writeln("AdjacencyList: Adding a vertex with a property.");
    foreach(VertexStorage; TypeTuple!(VecS, ListS)) {
        foreach(EdgeStorage; TypeTuple!(VecS, ListS)) {
            foreach(Directionality; TypeTuple!(DirectedS, UndirectedS, BidirectionalS)) {
                AdjacencyList!(VertexStorage, EdgeStorage, Directionality, string) g;
                auto v1 = g.addVertex("alpha");
                auto v2 = g.addVertex("beta");
                auto v3 = g.addVertex("gamma");

                foreach(x; zip(g.vertices(), ["alpha", "beta", "gamma"][])) {
                    assert (g[x[0]] == x[1], "Mismatched vertex descriptors");
                }
            }
        }
    }
}

unittest {
    writeln("AdjacencyList: Vertex properties are assignable.");
    foreach(VertexStorage; TypeTuple!(VecS, ListS)) {
        foreach(EdgeStorage; TypeTuple!(VecS, ListS)) {
            foreach(Directionality; TypeTuple!(DirectedS, UndirectedS, BidirectionalS)) {
                AdjacencyList!(VertexStorage, EdgeStorage, Directionality, string) g;
                auto v1 = g.addVertex("alpha");
                auto v2 = g.addVertex("beta");
                auto v3 = g.addVertex("gamma");

                assert (g[v2] == "beta");
                g[v2] = "narf";

                foreach(x; zip(g.vertices(), ["alpha", "narf", "gamma"][])) {
                    assert (g[x[0]] == x[1], "Mismatched vertex descriptors");
                }
            }
        }
    }
}

unittest {
    struct Test { int i; }

    writeln("AdjacencyList: Vertex properties are mutable.");
    foreach(VertexStorage; TypeTuple!(VecS, ListS)) {
        foreach(EdgeStorage; TypeTuple!(VecS, ListS)) {
            foreach(Directionality; TypeTuple!(DirectedS, UndirectedS, BidirectionalS)) {
                AdjacencyList!(VertexStorage, EdgeStorage, Directionality, Test) g;
                auto v1 = g.addVertex(Test(0));
                auto v2 = g.addVertex(Test(1));
                auto v3 = g.addVertex(Test(2));

                assert (g[v2].i == 1);
                g[v2].i = 42;
                assert (g[v2].i == 42);
            }
        }
    }
}}
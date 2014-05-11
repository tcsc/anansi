module spiderpig.adjacencylist;

import std.algorithm, std.conv, std.range, std.stdio,
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
    alias EdgeIndex = StorageIndex!EdgeStorage;

    struct EdgeDescriptor {
        package VertexDescriptor src;
        package EdgeIndex index;
    }
 
    enum IsUndirected = is(Directionality == UndirectedS);
    enum IsBidirectional = is(Directionality == BidirectionalS);

private:
    /** 
     *
     */
    static struct Edge {
        this(VertexDescriptor src, VertexDescriptor dst, 
             EdgeProperty value = EdgeProperty.init) 
        {
            _src = src;
            _dst = dst;
            static if (isNotNone!EdgeProperty) {
                _property = value;
            }
        }

        private VertexDescriptor _src;
        private VertexDescriptor _dst;

        public @property VertexDescriptor source() { return _src; }
        public @property VertexDescriptor target() { return _dst; }

        static if (isNotNone!EdgeProperty) {
            private EdgeProperty  _property;
            public @property ref inout(EdgeProperty) value() inout { 
                return _property; 
            } 
        }
    }

    static if (IsUndirected) {
        alias StoredEdge = List!(Edge).Node*;
    }
    else {
        alias StoredEdge = Edge;
    }

    static struct Vertex {
        public this(VertexProperty p = VertexProperty.init) {
            static if (isNotNone!VertexProperty) {
                _property = p;
            }
        }

        public this(this) {
            _outEdges = _outEdges.dup;
            static if (IsBidirectional) {
                _inEdges = _inEdges.dup;
            }
        }

        public auto addOutEdge(StoredEdge edge) {
            return _outEdges.push(edge);
        }

        public ref inout(StoredEdge) outEdge(EdgeIndex index) inout {
            return _outEdges.get_value(index);
        }

        public auto outEdges() {
            return _outEdges.indexRange();
        }

        private Storage!(EdgeStorage, StoredEdge) _outEdges;

        static if (IsBidirectional) {
            private Storage!(EdgeStorage, EdgeDescriptor) _inEdges;
            public void addInEdge(EdgeDescriptor edge) {
                _inEdges.push(edge);
            }
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

    static if(IsUndirected) { List!Edge _edges; }

public: 
    // ------------------------------------------------------------------------ 
    // Vertex operations
    // ------------------------------------------------------------------------

    VertexDescriptor addVertex(VertexProperty value = VertexProperty.init) {
        return _vertices.push(Vertex(value)).index;
    }

    @property vertexCount() const {
        return _vertices.length;
    }

    /**
     * Returns a forward range that yields the descriptors for each vertex in 
     * the graph. The order of the vertices is undefined.
     */
    @property auto vertices() {
        return _vertices.indexRange();
    }

    static if (!isNone!VertexProperty) {
        ref inout(VertexProperty) opIndex(VertexDescriptor v) inout {
            return _vertices.get_value(v).property;
        }
    }

public:
    // ------------------------------------------------------------------------ 
    // Edge operations
    // ------------------------------------------------------------------------

    alias AddEdgeResult = Tuple!(EdgeDescriptor, "edge", bool, "addedNew");

    AddEdgeResult addEdge(VertexDescriptor src, 
                          VertexDescriptor dst, 
                          EdgeProperty value = EdgeProperty()) {

        static if (IsUndirected) {
            Vertex* pSrc = &_vertices.get_value(src);
            Vertex* pDst = &_vertices.get_value(dst); 
            // TODO: check for parallel edge support here, and deal with it
            auto newEdge = _edges.insertBack(Edge(src, dst));
            auto index = pSrc.addOutEdge(newEdge).index;
            pDst.addOutEdge(newEdge);
            return AddEdgeResult(EdgeDescriptor(src, index), true);
        }
        else {
            auto newEdge = _vertices.get_value(src).addOutEdge(Edge(src, dst, value));
            auto descriptor = EdgeDescriptor(src, newEdge.index);
            static if(IsBidirectional) {
                if (newEdge.addedNew) { 
                    // if we added a new edge, rather than overwrote an existing one.
                    // Overwriting will only happen on graph types that don't support 
                    // parallel edges
                    _vertices.get_value(dst).addInEdge(descriptor);
                }
            }
            return AddEdgeResult(descriptor, newEdge.addedNew);
        }
    }

    VertexDescriptor source(EdgeDescriptor edge) {
        return edge.src;
    }

    VertexDescriptor target(EdgeDescriptor edge) {
        static if (IsUndirected) {
            return _vertices.get_value(edge.src).outEdge(edge.index).value.target;
        }
        else {
            return _vertices.get_value(edge.src).outEdge(edge.index).target;
        }
    }

    auto outEdges(VertexDescriptor vertex) {
        alias IndexRange = typeof(_vertices.get_value(vertex).outEdges());
        static struct OutEdgeRange {
            this(VertexDescriptor src, IndexRange r) { 
                _src = src;
                _r = r; 
            }
            @property bool empty() { return _r.empty; }
            @property EdgeDescriptor front() { 
                return EdgeDescriptor(_src, _r.front);
            } 
            void popFront() { _r.popFront(); }
            private IndexRange _r;
            private VertexDescriptor _src;
        }
        static assert(isInputRange!OutEdgeRange);
        static assert(is(ElementType!OutEdgeRange == EdgeDescriptor));
        return OutEdgeRange(vertex, _vertices.get_value(vertex).outEdges());
    }
}

// ----------------------------------------------------------------------------
// Unit Tests
// ----------------------------------------------------------------------------

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
}

unittest {
    writeln("AdjacencyList: Adding edges without properties");
    foreach(VertexStorage; TypeTuple!(VecS, ListS)) {
        foreach(EdgeStorage; TypeTuple!(VecS, ListS)) {
            foreach(Directionality; TypeTuple!(DirectedS, UndirectedS, BidirectionalS)) {
                alias Graph = AdjacencyList!(VertexStorage, EdgeStorage, Directionality);
                Graph g;
                auto vA = g.addVertex();
                auto vB = g.addVertex();
                auto vC = g.addVertex();
                auto vD = g.addVertex();

                auto addUniqueEdge = delegate(Graph.VertexDescriptor s, Graph.VertexDescriptor d) { 
                    auto tmp = g.addEdge(s, d);
                    assert(tmp.addedNew, Graph.stringof ~ ": Edge must be unique.");
                    return tmp.edge;
                };

                auto eAB = addUniqueEdge(vA, vB);
                auto eBC = addUniqueEdge(vB, vC);
                auto eCD = addUniqueEdge(vC, vD);
                auto eBD = addUniqueEdge(vB, vD);

                auto aOut = array(g.outEdges(vA));
                assert (aOut.length == 1, 
                        Graph.stringof ~ ": Expected A to have exactly one out edge, got " 
                        ~ to!string(aOut.length));

                assert (g.target(aOut[0]) == vB,
                        Graph.stringof ~ ": Expected A to connect to B");

                auto bOut = array(g.outEdges(vB));
                auto expected = g.IsUndirected ? 3 : 2; 
                assert (bOut.length == expected,
                    Graph.stringof ~ ": Expected " ~ to!string(expected) ~ 
                    " out edges on B, got " ~ to!string(bOut.length));
            }
        }
    }
}
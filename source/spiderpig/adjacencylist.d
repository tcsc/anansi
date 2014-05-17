module spiderpig.adjacencylist;

import std.algorithm,
       std.conv,
       std.range,
       std.stdio,
       std.traits,
       std.typecons,
       std.typetuple;
import spiderpig.container, spiderpig.traits;


struct AdjacencyList (alias VertexStorage = VecS,
                      alias EdgeStorage = VecS,
                      Directionality = DirectedS,
                      VertexProperty = NoProperty,
                      EdgeProperty = NoProperty)
{
public:
    alias VertexDescriptor = VertexStorage.IndexType; // StorageIndex!VertexStorage;
    alias EdgeIndex = EdgeStorage.IndexType; //StorageIndex!EdgeStorage;

    struct EdgeDescriptor {
        package VertexDescriptor src;
        package EdgeIndex index;
    }
 
    enum IsUndirected = is(Directionality == UndirectedS);
    enum IsBidirectional = is(Directionality == BidirectionalS);

private:
    /** 
     * The main storage object for edges. Holds the source and destination 
     * vertices for the graph, plus any property object. 
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
        public @property void source(VertexDescriptor v) { _src = v; }

        public @property VertexDescriptor target() { return _dst; }
        public @property void target(VertexDescriptor v) { _dst = v; }

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

    /**
     * The main storeage object for vertices. Maintains the collection of out- 
     * (and optionally in-) edges for the vertex, plus any property values.
     */
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

        public auto outEdgeIndexes() {
            return _outEdges.indexRange();
        }

        @property public auto outEdges() {
            return _outEdges[];
        }

        @property public size_t outDegree() const {
            return _outEdges.length;
        }

        private EdgeStorage.Store!StoredEdge _outEdges;

        static if (IsBidirectional) {
            private EdgeStorage.Store!(EdgeDescriptor) _inEdges;
            public void addInEdge(EdgeDescriptor edge) {
                _inEdges.push(edge);
            }

            auto inEdges() { return _inEdges[]; }

            @property public size_t inDegree() const {
                return _inEdges.length; 
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

    /** 
     * The main vertex store.
     */
    VertexStorage.Store!Vertex _vertices;

    static if(IsUndirected) {
        /** 
         * The main store for edge data when the graph is undirected. 
         */
        List!Edge _edges; 
    }

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

    static if (!VertexStorage.IndexesAreStable) {
        void rewriteEdgeVertices(VertexDescriptor vertex, ref Edge e) {
            e.source = _vertices.rewriteIndex(vertex, e.source);
            e.target = _vertices.rewriteIndex(vertex, e.target);        
        }
    }

    void removeVertex(VertexDescriptor vertex) {
        _vertices.erase(vertex);
        static if( !VertexStorage.IndexesAreStable ) {
            static if ( IsUndirected ) {
                foreach(ref e; _edges)
                    rewriteEdgeVertices(vertex, e);
            }
            else {
                foreach(ref v; _vertices) {
                    foreach(ref e; v.outEdges())
                        rewriteEdgeVertices(vertex, e);
                }
            }
        }
    }

public:
    // ------------------------------------------------------------------------ 
    // Edge operations
    // ------------------------------------------------------------------------

    alias AddEdgeResult = Tuple!(EdgeDescriptor, "edge", bool, "addedNew");

    /**
     * Adds an edge to the graph.
     */
    AddEdgeResult addEdge(VertexDescriptor src, 
                          VertexDescriptor dst, 
                          EdgeProperty value = EdgeProperty.init) {

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

    /**
     * Fetches the descriptor of the source vertex of the given edge.
     * \param edge The descriptor of the edge to query.
     * \returns The descriptor of the supplied edge's source vertex.
     */
    VertexDescriptor source(EdgeDescriptor edge) {
        return edge.src;
    }

    /**
     * Fetches the descriptor of the target vertex of the supplied edge.
     *
     * \param edge The descriptor of the edge you want to query.
     */
    VertexDescriptor target(EdgeDescriptor edge) {
        static if (IsUndirected) {
            auto pEdge = _vertices.get_value(edge.src).outEdge(edge.index).value;
            return pEdge.target == edge.src ? pEdge.source : pEdge.target;
        }
        else {
            return _vertices.get_value(edge.src).outEdge(edge.index).target;
        }
    }

    /**
     * Lists the outbound edges of a given vertex.
     * \param vertex The descriptor of the vertex to query.
     * \returns Returns a range containing the edge descriptors of the supplied
     *          vertex's outbound edges. 
     */
    auto outEdges(VertexDescriptor vertex) {
        alias IndexRange = typeof(_vertices.get_value(vertex).outEdgeIndexes());
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
        return OutEdgeRange(vertex, _vertices.get_value(vertex).outEdgeIndexes());
    }

    size_t outDegree(VertexDescriptor vertex) const {
        return _vertices.get_value(vertex).outDegree;
    }

    static if (IsBidirectional) {
        size_t inDegree(VertexDescriptor vertex) const {
            return _vertices.get_value(vertex).inDegree;
        }

        auto inEdges(VertexDescriptor vertex) {
            return _vertices.get_value(vertex).inEdges();
        }
    } 
}

// ----------------------------------------------------------------------------
// Unit Tests
// ----------------------------------------------------------------------------

unittest {
    writeln("AdjacencyList: Custom storage type");

    struct ArrayS {
        alias IndexType = size_t;
        enum IndexesAreStable = true;

        static struct Store(ValueType) {
            auto push(ValueType value) {
                size_t rval = _store.length;
                _store ~= value;
                return PushResult!(typeof(rval))(rval, true);
            }

            void erase(IndexType index) {
                assert (false, "Not Implemented");
            }

            auto indexRange() {
                return iota(0, _store.length);
            }

            ref inout(ValueType) get_value(IndexType index) inout {
                return _store[index];
            }

            @property auto dup() {
                return Store(_store.dup);
            }

            @property size_t length() const {
                return _store.length;
            }

            ValueType[] _store;

            alias _store this;
        }
    }

    AdjacencyList!(ArrayS, ArrayS, DirectedS, char, string) g;
    auto v = g.addVertex('a');
    assert (g[v] == 'a');
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
                    assert (g[x[0]] == x[1], "Mismatched vertex properties");
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
    writeln("AdjacencyList: Erasing a vertex.");
    foreach(VertexStorage; TypeTuple!(VecS, ListS)) {
        foreach(EdgeStorage; TypeTuple!(VecS, ListS)) {
            foreach(Directionality; TypeTuple!(DirectedS, UndirectedS, BidirectionalS)) {
                alias Graph = AdjacencyList!(VertexStorage, EdgeStorage, Directionality, char, string);
                Graph g;

                /* artificial scope for namespacing */ {
                    auto a = g.addVertex('a');
                    auto b = g.addVertex('b');
                    auto c = g.addVertex('c');
                    
                    auto ac = g.addEdge(a, c, "ac");
                    auto ca = g.addEdge(c, a, "ca");

                    g.removeVertex(b);
                }

                assert (g.vertexCount == 2, 
                    Graph.stringof ~ ": Expected vertex count to be 2, got: " ~ 
                    to!string(g.vertexCount));

                // assert that we only have the vertices we expect
                auto vertices = array(g.vertices());
                foreach(x; zip(vertices, ['a', 'c'])) {
                    assert (g[x[0]] == x[1], 
                        Graph.stringof ~ ": Mismatched vertex descriptors");
                }

                // assert the a -> c edge still holds
                auto a = vertices[0];
                auto c = vertices[1];
                auto ac = g.outEdges(a).front;
                assert (g.source(ac) == a, 
                    Graph.stringof ~ ": Source(ac) should be a");

                assert (g.target(ac) == c, 
                    Graph.stringof ~ ": Target(ac) should be c");

                // assert the c -> a edge still holds
                auto ca = g.outEdges(c).front;
                assert (g.source(ca) == c, 
                    Graph.stringof ~ ": Source(ca) should be c");

                assert (g.target(ca) == a, 
                    Graph.stringof ~ ": Target(ca) should be a");

            }
        }
    }
}

version (unittest) {
    void checkEdges(Graph)(ref Graph g, 
                           string name,
                           Graph.VertexDescriptor src,
                           Graph.VertexDescriptor[] outTargets,
                           Graph.VertexDescriptor[] inTargets) {
        auto outEdges = array(g.outEdges(src));
        auto outDegree = g.outDegree(src);
        assert (outDegree == outTargets.length, 
                Graph.stringof ~ ": Expected " ~ name ~ 
                " to have out degree of " ~ to!string(outTargets.length) ~ 
                ", got " ~ to!string(outDegree));

        assert (outEdges.length == outTargets.length, 
                Graph.stringof ~ ": Expected " ~ name ~ " to have exactly " ~
                to!string(outTargets.length) ~ " out edge(s), got " ~
                to!string(outEdges.length));

        foreach (t; outTargets) {
            assert (any!(e => g.target(e) == t)(outEdges), 
                    Graph.stringof ~ ": Expected target from " ~ name ~ 
                    " was not in out edges.");
        }

        static if (g.IsBidirectional) {
            auto inDegree = g.inDegree(src);
            assert (inDegree == inTargets.length, 
                    Graph.stringof ~ ": Expected " ~ name ~ 
                    " to have in degree of " ~ to!string(inTargets.length) ~ 
                    ", got " ~ to!string(inDegree));

            auto inEdges = array(g.inEdges(src));
            foreach (t; inTargets) {
                assert (any!(e => g.source(e) == t)(inEdges), 
                        Graph.stringof ~ ": Expected source in " ~ name ~ 
                        " was not in in-edges.");
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

                // Graph layout
                //      B
                //    / | \
                //   A  |  C
                //      | /
                //      D

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

                checkEdges!Graph(g, "A", vA, [vB], []);
                checkEdges!Graph(g, "B", vB, g.IsUndirected ? [vA, vC, vD] : [vC, vD], [vA]);
                checkEdges!Graph(g, "C", vC, g.IsUndirected ? [vB, vD] : [vD], [vB]);
                checkEdges!Graph(g, "D", vD, g.IsUndirected ? [vB, vC] : [], [vB, vC]);
            }
        }
    }
}
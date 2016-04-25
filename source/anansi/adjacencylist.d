module anansi.adjacencylist;

import std.algorithm,
       std.conv,
       std.range,
       std.stdio,
       std.traits,
       std.typecons,
       std.typetuple;
import anansi.container, anansi.traits;


struct AdjacencyList (alias VertexStorage = VecS,
                      alias EdgeStorage = VecS,
                      Directionality = DirectedS,
                      VertexProperty = NoProperty,
                      EdgeProperty = NoProperty)
{
public:
    alias VertexDescriptor = VertexStorage.IndexType;

    enum IsUndirected = is(Directionality == UndirectedS);
    enum IsBidirectional = is(Directionality == BidirectionalS);
    enum IsDirected = !(IsUndirected || IsBidirectional);

    /**
     * The main storage object for edges. Holds the source and destination
     * vertices for the graph, plus any property object.
     */
    private static struct Edge {
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

        private EdgeProperty  _property;
        public @property ref inout(EdgeProperty) value() inout {
            return _property;
        }
    }

    private alias EdgeList = List!Edge;
    private alias EdgeIndex = EdgeList.Node*;

    /**
     * A handle that can be used by callers to identify a given edge.
     */
    public static struct EdgeDescriptor {
        package VertexDescriptor src;
        package VertexDescriptor dst;
        package const(EdgeList.Node)* edgeIndex;
    }

    /**
     * The main storeage object for vertices. Maintains the collection of out-
     * (and optionally in-) edges for the vertex, plus any property values.
     */
    private static struct Vertex {
        public alias EdgeContainer = EdgeStorage.Store!EdgeIndex;

        private EdgeContainer _outEdges;
        static if (IsBidirectional) {
            private EdgeContainer _inEdges;
        }

        public this(VertexProperty p /*= VertexProperty.init*/) {
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

        public auto addOutEdge(EdgeIndex edge) {
            return _outEdges.push(edge);
        }

        public void eraseOutEdge(EdgeIndex edge) {
            eraseEdge(_outEdges, edge);
        }

        private static void eraseEdge(ref EdgeContainer edges, EdgeIndex edge) {
            auto r = find(edges[], edge);
            assert (!r.empty, "Attempt to remove an edge that doesn't exist");
            edges.eraseFrontOfRange(r);
        }

        auto outEdges() const { return _outEdges[]; }

        @property public size_t outDegree() const {
            return _outEdges.length;
        }

        static if (IsBidirectional) {
            public void addInEdge(EdgeIndex edge) {
                _inEdges.push(edge);
            }

            public void eraseInEdge(EdgeIndex edge) {
                eraseEdge(_inEdges, edge);
            }

            auto inEdges() const { return _inEdges[]; }

            @property public size_t inDegree() const {
                return _inEdges.length;
            }
        }

        static if (isNotNone!VertexProperty) {
            private VertexProperty _property;

            public @property ref inout(VertexProperty) property() inout {
                return _property;
            }
        }
    }

    /**
     * The main vertex store.
     */
    VertexStorage.Store!Vertex _vertices;

    /**
     * The main edge store
     */
    EdgeList _edges;

public:
    // ------------------------------------------------------------------------
    // Vertex operations
    // ------------------------------------------------------------------------

    /**
     * Adds a new vertex to the graph.
     *
     * Params:
     *   value = The property value to associate with the vertex, if any.
     *
     * Returns: Returns a VertexDescriptor referencing the newly-added vertex.
     */
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
    @property auto vertices() inout {
        return _vertices.indexRange();
    }

    static if (!isNone!VertexProperty) {
        ref inout(VertexProperty) opIndex(VertexDescriptor v) inout {
            return _vertices.get_value(v).property;
        }
    }

    /**
     * Removes a vertex from the graph. The complexity of this operaton
     * varies with the storage class. For storage classes that have
     * stable indexes, this is O(1). For classes with unstable indexes
     * this is at least O(n), where n is the number of edges in the graph,
     * due to the VertexDescriptors in all the edges having to be fixed up.
     *
     * This is the *minimum* complexity, because the underlying storage may
     * impose its own complexity costs on erasing the vertex itself as well.
     *
     * Params:
     *   vertex = The VertexDescriptor of the vertex to erase.
     */
    void removeVertex(VertexDescriptor vertex) {
        _vertices.erase(vertex);
        static if( !VertexStorage.IndexesAreStable ) {
            foreach(ref e; _edges[]) {
                e.source = _vertices.rewriteIndex(vertex, e.source);
                e.target = _vertices.rewriteIndex(vertex, e.target);
            }
        }
    }

public:
    // ------------------------------------------------------------------------
    // Edge operations
    // ------------------------------------------------------------------------

    /**
     * A tuple with some names to help unpacking the result of an addEdge call.
     */
    alias AddEdgeResult = Tuple!(EdgeDescriptor, "edge", bool, "addedNew");

    /**
     * Adds an edge to the graph.
     *
     * Params:
     *  src = The VertexDescriptor of the edge's starting point.
     *  dst = The VertexDescriptor of the new edge's end point.
     *  value = The value to associate with the new edge, if any.
     *
     * Returns: Returns an AddEdgeResult value, containinf the descriptor of
     *          the edge, and a flag to let you know if it was newly created
     *          (true), or the edge already esisted and the graph type doesn't
     *          support parallel edges, so the returned descriptor refers to
     *          the pre-existing edge (false).
     */
    AddEdgeResult addEdge(VertexDescriptor src,
                          VertexDescriptor dst,
                          EdgeProperty value = EdgeProperty.init) {

        EdgeIndex newEdge = _edges.insertBack(Edge(src, dst, value));
        Vertex* pSrc = &_vertices.get_value(src);
        pSrc.addOutEdge(newEdge);

        static if (IsUndirected) {
            Vertex* pDst = &_vertices.get_value(dst);
            pDst.addOutEdge(newEdge);
        }
        else static if (IsBidirectional) {
            Vertex* pDst = &_vertices.get_value(dst);
            pDst.addInEdge(newEdge);
        }

        return AddEdgeResult(EdgeDescriptor(src, dst, newEdge), true);
    }

    /**
     * Removes an edge from the graph.
     */
    void removeEdge(EdgeDescriptor edge) {
        VertexDescriptor src = cast(VertexDescriptor) edge.src;
        VertexDescriptor dst = cast(VertexDescriptor) edge.dst;
        Vertex* srcVertex = &_vertices.get_value(src);
        EdgeIndex idx = cast(EdgeIndex) edge.edgeIndex;

        srcVertex.eraseOutEdge(idx);

        static if (IsUndirected) {
            Vertex* dstVertex = &_vertices.get_value(dst);
            dstVertex.eraseOutEdge(idx);
        }
        else static if (IsBidirectional) {
            Vertex* dstVertex = &_vertices.get_value(dst);
            dstVertex.eraseInEdge(idx);
        }

        _edges.remove(idx);
    }

    /**
     * Fetches the descriptor of the source vertex of the given edge.
     *
     * Params:
     *   edge = The descriptor of the edge to query.
     *
     * Returns: The descriptor of the supplied edge's source vertex.
     */
    VertexDescriptor source(EdgeDescriptor edge) const {
        return cast(VertexDescriptor) edge.src;
    }

    /**
     * Fetches the descriptor of the target vertex of the supplied edge.
     *
     * Params:
     *   edge = The descriptor of the edge you want to query.
     */
    VertexDescriptor target(EdgeDescriptor edge) const {
        return cast(VertexDescriptor) edge.dst;
    }

    /**
     * Lists the outbound edges of a given vertex.
     *
     * Params:
     *   vertex = The descriptor of the vertex to query.
     *
     * Returns: Returns a range containing the edge descriptors of the
     *          supplied vertex's outbound edges.
     */
    auto outEdges(VertexDescriptor vertex) const {
        static struct OutEdgeRange {
            alias EdgeRange = Vertex.EdgeContainer.ConstRange;

            this(VertexDescriptor src, EdgeRange r) {
                _src = src;
                _r = r;
            }

            @property bool empty() { return _r.empty; }

            @property EdgeDescriptor front() {
                auto edge = _r.front;

                static if (IsUndirected) {
                    auto s = edge.value._src;
                    auto d = edge.value._dst;
                    auto src = (s == _src) ? s : d;
                    auto dst = (s == _src) ? d : s;
                }
                else{
                    auto src = edge.value._src;
                    auto dst = edge.value._dst;
                }

                return EdgeDescriptor(cast(VertexDescriptor)src,
                                      cast(VertexDescriptor)dst,
                                      cast(EdgeIndex)(edge));
            }

            void popFront() { _r.popFront(); }

            private EdgeRange _r;
            private VertexDescriptor _src;
        }

        static assert(isInputRange!OutEdgeRange);
        static assert(is(ElementType!OutEdgeRange == EdgeDescriptor));

        return OutEdgeRange(vertex, _vertices.get_value(vertex).outEdges());
    }

    size_t outDegree(VertexDescriptor vertex) const {
        return _vertices.get_value(vertex).outDegree;
    }

    static if (IsBidirectional) {
        size_t inDegree(VertexDescriptor vertex) const {
            return _vertices.get_value(vertex).inDegree;
        }

        auto inEdges(VertexDescriptor vertex) const {
            static struct InEdgeRange {
                alias EdgeRange = Vertex.EdgeContainer.ConstRange;

                this(EdgeRange r) { _r = r; }

                @property bool empty() { return _r.empty; }

                @property EdgeDescriptor front() {
                    auto edge = _r.front;
                    auto s = edge.value._src;
                    auto d = edge.value._dst;
                    return EdgeDescriptor(cast(VertexDescriptor)s,
                                          cast(VertexDescriptor)d,
                                          cast(EdgeIndex)edge);
                }

                void popFront() { _r.popFront(); }

                private EdgeRange _r;
                private VertexDescriptor _src;
            }

            static assert(isInputRange!InEdgeRange);
            static assert(is(ElementType!InEdgeRange == EdgeDescriptor));

            return InEdgeRange(_vertices.get_value(vertex).inEdges());
        }
    }

    static if (!isNone!EdgeProperty) {
        ref EdgeProperty opIndex(EdgeDescriptor e) {
            return (cast(EdgeIndex)e.edgeIndex).valueRef.value;
        }

        ref const(EdgeProperty) opIndex(EdgeDescriptor e) const {
            return e.edgeIndex.valueRef.value;
        }
    }

    /**
     * Fetches the total number of edges in the graph. For debugging purposes
     * only.
     */
    @property size_t edgeCount() const {
        return _edges.length;
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
            alias Range = ValueType[];

            auto push(ValueType value) {
                size_t rval = _store.length;
                _store ~= value;
                return PushResult!(typeof(rval))(rval, true);
            }

            void erase(IndexType index) {
                assert (false, "Not Implemented");
            }

            void eraseFrontOfRange(ValueType[] range) {
                assert (false, "Not Implemented");
            }

            auto indexRange() const {
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

            alias ConstRange = const(ValueType)[];

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
    writeln("AdjacencyList: Adding edges works as expected.");
    foreach(VertexStorage; TypeTuple!(VecS, ListS)) {
        foreach(EdgeStorage; TypeTuple!(VecS, ListS)) {
            foreach(Directionality; TypeTuple!(DirectedS, UndirectedS, BidirectionalS)) {
                alias Graph = AdjacencyList!(VertexStorage, EdgeStorage, Directionality, char, string);

                Graph g;

                // Graph layout
                //      B
                //    / | \
                //   A  |  C
                //      | /
                //      D

                auto vA = g.addVertex('a');
                auto vB = g.addVertex('b');
                auto vC = g.addVertex('c');
                auto vD = g.addVertex('d');

                auto addUniqueEdge = delegate(Graph.VertexDescriptor s, Graph.VertexDescriptor d) {
                    auto tmp = g.addEdge(s, d, to!string(g[s]) ~ " --> " ~ to!string(g[d]) );
                    assert(tmp.addedNew, Graph.stringof ~ ": Edge must be unique.");
                    return tmp.edge;
                };

                auto eAB = addUniqueEdge(vA, vB);
                auto eBC = addUniqueEdge(vB, vC);
                auto eCD = addUniqueEdge(vC, vD);
                auto eBD = addUniqueEdge(vB, vD);

                assert (g.edgeCount == 4, "edgeCount should be 4");

                checkEdges!Graph(g, "A", vA, [vB], []);
                checkEdges!Graph(g, "B", vB, g.IsUndirected ? [vA, vC, vD] : [vC, vD], [vA]);
                checkEdges!Graph(g, "C", vC, g.IsUndirected ? [vB, vD] : [vD], [vB]);
                checkEdges!Graph(g, "D", vD, g.IsUndirected ? [vB, vC] : [], [vB, vC]);
            }
        }
    }
}

unittest {
    writeln("AdjacencyList: Removing edges works as expected.");
    foreach(VertexStorage; TypeTuple!(VecS, ListS)) {
        foreach(EdgeStorage; TypeTuple!(VecS, ListS)) {
            foreach(Directionality; TypeTuple!(DirectedS, UndirectedS, BidirectionalS)) {
                alias Graph = AdjacencyList!(VertexStorage, EdgeStorage, Directionality, char, string);

                Graph g;

                // Graph layout
                //      B
                //    / |
                //   A  |  C
                //      | /
                //      D

                auto vA = g.addVertex('a');
                auto vB = g.addVertex('b');
                auto vC = g.addVertex('c');
                auto vD = g.addVertex('d');

                auto addUniqueEdge = delegate(Graph.VertexDescriptor s, Graph.VertexDescriptor d) {
                    auto tmp = g.addEdge(s, d, to!string(g[s]) ~ " --> " ~ to!string(g[d]) );
                    assert(tmp.addedNew, Graph.stringof ~ ": Edge must be unique.");
                    return tmp.edge;
                };

                auto eAB = addUniqueEdge(vA, vB);
                auto eBC = addUniqueEdge(vB, vC);
                auto eCD = addUniqueEdge(vC, vD);
                auto eBD = addUniqueEdge(vB, vD);

                assert (g.edgeCount == 4, "edgeCount should be 4");

                g.removeEdge(eBC);

                assert (g.edgeCount == 3, "edgeCount should be 3");

                checkEdges!Graph(g, "A", vA, [vB], []);
                checkEdges!Graph(g, "B", vB, g.IsUndirected ? [vA, vD] : [vD], [vA]);
                checkEdges!Graph(g, "C", vC, g.IsUndirected ? [vD] : [vD], []);
                checkEdges!Graph(g, "D", vD, g.IsUndirected ? [vB, vC] : [], [vB, vC]);

                assert (g[eAB] == "a --> b");
                assert (g[eBD] == "b --> d");
                assert (g[eCD] == "c --> d");
            }
        }
    }
}

unittest {
    writeln("AdjacencyList: Edge properties are mutable.");

        foreach(VertexStorage; TypeTuple!(VecS, ListS)) {
        foreach(EdgeStorage; TypeTuple!(VecS, ListS)) {
            foreach(Directionality; TypeTuple!(DirectedS, UndirectedS, BidirectionalS)) {
                alias Graph = AdjacencyList!(VertexStorage, EdgeStorage, Directionality, char, string);

                Graph g;

                // Graph layout
                //      B
                //    / |
                //   A  |  C
                //      | /
                //      D

                auto vA = g.addVertex('a');
                auto vB = g.addVertex('b');
                auto vC = g.addVertex('c');
                auto vD = g.addVertex('d');

                auto addUniqueEdge = delegate(Graph.VertexDescriptor s, Graph.VertexDescriptor d) {
                    auto tmp = g.addEdge(s, d, to!string(g[s]) ~ " --> " ~ to!string(g[d]) );
                    assert(tmp.addedNew, Graph.stringof ~ ": Edge must be unique.");
                    return tmp.edge;
                };

                auto eAB = addUniqueEdge(vA, vB);
                auto eBC = addUniqueEdge(vB, vC);
                auto eCD = addUniqueEdge(vC, vD);
                auto eBD = addUniqueEdge(vB, vD);

                assert (g[eBC] == "b --> c", "Property should be readable");
                g[eBC] = "some value";
                assert (g[eBC] == "some value");
            }
        }
    }
}
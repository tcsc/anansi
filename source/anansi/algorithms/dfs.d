/**
 * Implements depth-first search over graphs.
 */
module anansi.algorithms.dfs;

import std.exception;

import anansi.types,
       anansi.traits,
       anansi.container.stack;

/**
 * Compile time test to check if a given type can be considered a DFS visitor.
 */
template isDfsVisitor (V) {
    enum bool isDfsVisitor = is(typeof(
    (inout int = 0) {

    }));
}


/**
 * A default implementation of the depth-first-search visitor concept. More 
 * specialised visitors can delegate the bits that they don't care about
 * to an instance of NullVisitor without having to re-implement them. 
 *
 * Also servers as a handy point for documenting the visitor interface.
 */
struct NullVisitor(GraphT) if (isGraph!GraphT) {
    /// A vertex in a GraphT
    alias Vertex = GraphT.VertexDescriptor;

    /// An edge in a GraphT
    alias Edge = GraphT.EdgeDescriptor;

    /// Called when a vertex is set to its initial state, before the search.
    void initVertex(ref const(GraphT) g, Vertex v) {};

    /// Called when a vertex is identified as the root of a depth-first spanning 
    /// tree
    void startVertex(ref const(GraphT) g, Vertex v) {};

    /// Called when a vertex is first encountered during the search.
    void discoverVertex(ref const(GraphT) g, Vertex v) {};

    /// Called when an edge is being expanded.
    void examineEdge(ref const(GraphT) g, Edge e) {};

    /// Called when an edge has been identified as part of the current 
    /// spanning tree.
    void treeEdge(ref const(GraphT) g, Edge e) {};

    /// Called when an edge has been identified as part of a cycle
    void backEdge(ref const(GraphT) g, Edge e) {};

    /// Called when an edge crosses to a pre-existing spanning tree
    void forwardOrCrossEdge(ref const(GraphT) g, Edge e) {};

    /// Called whan all of the adjacent nodes of a vertex have been examined.
    void finishVertex(ref const(GraphT) g, Vertex e) {};
}

/**
 * Performs a depth-first traversal of the graph, which can be customised
 * using a visitor object. Note that disconnected graphs will still be 
 * entirely traversed - this function will walk the spanning tree of each  
 * disconnected component (in random order). 
 *
 * Params:
 *    GraphT = The type of the graph object to traverse. Must model the 
 *             incidence graph concept.
 *    VertexDescriptorT = The descriptor type for vertices in a GraphT.
 *    VisitorT = The visitor type.
 *    ColourMapT = The type of the property map that will be used to control 
 *                 the graph traversal. Must model a property map that stores 
 *                 Colours keyed by a VertexDescriptorT. 
 */
template depthFirstSearch(GraphT, 
                          VertexDescriptorT,
                          VisitorT = NullVisitor!GraphT,
                          ColourMapT = Colour[VertexDescriptorT]) {

    static assert (isIncidenceGraph!GraphT);
    static assert (is(VertexDescriptorT == GraphT.VertexDescriptor));
    static assert (isPropertyMap!(ColourMapT, GraphT.VertexDescriptor, Colour));
    static assert (isDfsVisitor!VisitorT);

    /**
     * Params:
     *   graph = The graph object to traverse.
     *   root = The vertex to serve as the starting point.
     *   colourMap = The colour map used to control the expansion of edges
     *               and verices in the graph. This will be totally re-
     *               initialised before the traversal begins. 
     *   visitor = A visitor object that will be notified of various events 
     *             during the traversal. 
     */
    void depthFirstSearch(ref const(GraphT) graph,
                          VertexDescriptorT root,
                          ref ColourMapT colourMap,
                          VisitorT visitor = VisitorT.init) {
        foreach(v; graph.vertices()) {
            colourMap[v] = Colour.White;
            visitor.initVertex(graph, v);
        }

        visitor.startVertex(graph, root);
        depthFirstVisit(graph, root, colourMap, visitor);

        foreach(v; graph.vertices()) {
            if (colourMap[v] == Colour.White) {
                visitor.startVertex(graph, root);
                depthFirstVisit(graph, v, colourMap, visitor);
            }
        }
    }
}

/**
 * Performs a depth-first traversal of the graph, which can be customised
 * using a visitor object. The main difference between this function and 
 * depthFirstSearch is that depthFirstSearch will initialise the 
 * supplied colour map, but depthFirstVisit will use it as-is. 
 *
 * Use this function if you need to efficiently make multiple passes over 
 * non-overlappng parts of the same graph, or depthFirstSearch if you just
 * want to walk over the whole thing. 
 *
 * Params:
 *    GraphT = The type of the graph object to traverse. Must model the 
 *             incidence graph concept.
 *    VertexDescriptorT = The descriptor type for vertices in a GraphT.
 *    VisitorT = The visitor type.
 *    ColourMapT = The type of the property map that will be used to control 
 *                 the graph traversal. Must model a property map that stores 
 *                 Colours keyed by a VertexDescriptorT. 
 */
template depthFirstVisit(GraphT,
                         VertexDescriptorT,
                         VisitorT = NullVisitor!GraphT,
                         ColourMapT = Colour[VertexDescriptorT]) {

    static assert (isIncidenceGraph!GraphT);
    static assert (is(VertexDescriptorT == GraphT.VertexDescriptor));
    static assert (isPropertyMap!(ColourMapT, GraphT.VertexDescriptor, Colour));
    static assert (isDfsVisitor!VisitorT);

    /**
     * Params:
     *   graph = The graph object to traverse.
     *   root = The vertex to serve as the starting point.
     *   colourMap = The colour map used to control the expansion of edges
     *               and verices in the graph.
     *   visitor = A visitor object that will be notified of various events 
     *             during the traversal. 
     */
    void depthFirstVisit(ref const(GraphT) graph,
                         VertexDescriptorT root,
                         ref ColourMapT colourMap,
                         VisitorT visitor = VisitorT.init) {
        static struct VertexInfo {
            alias EdgeRange = typeof(graph.outEdges(VertexDescriptorT.init));
            VertexDescriptorT vertex;
            EdgeRange edges;
        }

        Stack!VertexInfo stack;

        // set up the initial point of departure
        stack.push(VertexInfo(root, graph.outEdges(root)));
        colourMap[root] = Colour.Grey; 
        visitor.discoverVertex(graph, root);

        while (!stack.empty) {
            auto u = stack.front.vertex;
            auto edges = stack.front.edges;
            stack.pop();

            // not using foreach because we'll need access to the modified range 
            // later on...
            while (!edges.empty) {
                auto e = edges.front; 
                edges.popFront();

                visitor.examineEdge(graph, e);
                auto v = graph.target(e);

                switch (colourMap[v]) {
                    case Colour.White:
                        visitor.treeEdge(graph, e);
                        colourMap[v] = Colour.Grey;
                        visitor.discoverVertex(graph, v);
                        stack.push(VertexInfo(u, edges));

                        edges = graph.outEdges(v);
                        u = v;
                        break;

                    case Colour.Grey:
                        visitor.backEdge(graph, e);
                        break;

                    case Colour.Black:
                        visitor.forwardOrCrossEdge(graph, e);
                        break;

                    default:
                        enforce(false, "Unexpected vertex colour");
                }
            }

            colourMap[u] = Colour.Black;
            visitor.finishVertex(graph, u);
        }
    }
}

version (unittest) {
    import std.algorithm, std.conv, std.stdio;
    import anansi.adjacencylist, anansi.traits;

    int indexOf(ValueT)(ValueT[] haystack, ValueT needle) {
        foreach(int n, v; haystack) {
            if (v == needle) return n; 
        }
        return -1;
    }

    bool all(RangeT, DelegateT)(RangeT range, DelegateT d = DelegateT.init) {
        foreach (x; range) {
            if (!d(x)) return false;
        }
        return true;
    }

    private struct TestGraph(GraphT) {
        GraphT graph;
        GraphT.VertexDescriptor[char] vertices;
    };

    private TestGraph!GraphT MakeTestGraph(GraphT)() {
        GraphT graph;
        auto a = graph.addVertex('a');
        auto b = graph.addVertex('b');
        auto c = graph.addVertex('c');
        auto d = graph.addVertex('d');
        auto e = graph.addVertex('e');
        auto f = graph.addVertex('f');
        auto g = graph.addVertex('g');

        // *----------------*
        // |                |
        // |     /-> b ->\ /
        // *--> a         e -> f  g
        //       \-> c ->/
        //            \-> d

        graph.addEdge(a, b, "a -> b"); graph.addEdge(b, e, "b -> e");
        graph.addEdge(a, c, "a -> c"); graph.addEdge(c, e, "c -> e");
        graph.addEdge(e, f, "e -> f");
        graph.addEdge(e, a, "e -> a");
        graph.addEdge(c, d, "c -> d");

        GraphT.VertexDescriptor[char] vertices;
        vertices = reduce!((acc, v) { acc[graph[v]] = v; return acc; })(
            vertices, [a, b, c, d, e, f, g]);

        return TestGraph!GraphT(graph, vertices);
    }

    private alias G = AdjacencyList!(VecS, VecS, DirectedS, char, string); 
    private alias Vertex = G.VertexDescriptor;
    private alias Edge = G.EdgeDescriptor;
}

unittest {
    writeln("DFS: Vertices are discovered exactly once, and siblings discovered " ~
            "after children.");

    static struct Visitor {
        this(ref G graph, ref char[] discoveryOrder) {
            _graph = &graph;
            _discoveryOrder = &discoveryOrder;
        }

        void discoverVertex(ref const(G) g, Vertex v) {
            (*_discoveryOrder) ~= (*_graph)[v];
        }

        NullVisitor!G impl;
        alias impl this;

        G* _graph;
        char[]* _discoveryOrder;
    }
    char[] discoveryOrder;
    Colour[Vertex] colourMap;

    auto testGraph = MakeTestGraph!G(); 

    depthFirstSearch(testGraph.graph,
                     testGraph.vertices['a'], 
                     colourMap, 
                     Visitor(testGraph.graph, discoveryOrder));

    // Assert that each vertex is examined, and examined exactly once
    assert (discoveryOrder.length == 7,
        "Expected 7 entries in discovery order array, got " ~
        to!string(discoveryOrder.length));

    auto keyExists = delegate(char v) { return indexOf(discoveryOrder, v) >= 0; };
    
    assert (all(testGraph.vertices.keys, keyExists),
        "Expected all vertices to appear in the discovery order list: " ~
        discoveryOrder);

    // Assert that the source vertex is examined
    assert (indexOf(discoveryOrder, 'a') == 0,
        "Expected Vertex A to be the first vertex discovered.");

    // Assert that the vertices are enumerated depth first
    assert (indexOf(discoveryOrder, 'f') < indexOf(discoveryOrder, 'c'), 
        "Expected vertex F to appear before vertex C.");
 
    assert (indexOf(discoveryOrder, 'f') < indexOf(discoveryOrder, 'd'), 
        "Expected vertex F to appear before vertex D.");
}
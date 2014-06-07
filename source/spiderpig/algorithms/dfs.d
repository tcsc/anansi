/**
 * Implements depth-first search over graphs.
 */
module spiderpig.algorithms.dfs;

import std.exception;

import spiderpig.types,
       spiderpig.container.stack;

/**
 * Compile time test to check if a given type can be considered a DFS visitor.
 */
template isDfsVisitor (V) {
    enum bool isDfsVisitor = is(typeof(
    (inout int = 0) {

    }));
}


/**
 * A default implementation of the depth-first-search visitor concept that 
 * more specialised visitors can delegate the bits that they don't care about
 * to.
 */
struct NullVisitor(GraphT) {
    alias Vertex = GraphT.VertexDescriptor;
    alias Edge = GraphT.EdgeDescriptor;

    void initVertex(ref const(GraphT) g, Vertex v) {};
    void startVertex(ref const(GraphT) g, Vertex v) {};
    void discoverVertex(ref const(GraphT) g, Vertex v) {};
    void examineEdge(ref const(GraphT) g, Edge e) {};
    void treeEdge(ref const(GraphT) g, Edge e) {};
    void backEdge(ref const(GraphT) g, Edge e) {};
    void forwardOrCrossEdge(ref const(GraphT) g, Edge e) {};
    void finishVertex(ref const(GraphT) g, Vertex e) {};
}

template depthFirstSearch(GraphT, 
                          VertexDescriptorT,
                          VisitorT = NullVisitor!GraphT,
                          VertexColourMapT = Colour[VertexDescriptorT]) {

    static assert (isIncidenceGraph!GraphT);
    static assert (is(VertexDescriptorT == GraphT.VertexDescriptor));
    static assert (isPropertyMap!(VertexColourMapT, GraphT.VertexDescriptor, Colour));
    static assert (isDfsVisitor!VisitorT);

    void depthFirstSearch(ref const(GraphT) graph,
                          VertexDescriptorT root,
                          ref VertexColourMapT vertexColourMap,
                          VisitorT visitor = VisitorT.init) {
        foreach(v; graph.vertices()) {
            vertexColourMap[v] = Colour.White;
            visitor.initVertex(graph, v);
        }

        depthFirstVisit(graph, root, vertexColourMap, visitor);

        foreach(v; graph.vertices()) {
            if (vertexColourMap[v] == Colour.White) {
                depthFirstVisit(graph, root, vertexColourMap, visitor);
            }
        }
    }
}

template depthFirstVisit(GraphT,
                         VertexDescriptorT,
                         VisitorT = NullVisitor!GraphT,
                         VertexColourMapT = Colour[VertexDescriptorT]) {

    static assert (isIncidenceGraph!GraphT);
    static assert (is(VertexDescriptorT == GraphT.VertexDescriptor));
    static assert (isPropertyMap!(VertexColourMapT, GraphT.VertexDescriptor, Colour));
    static assert (isDfsVisitor!VisitorT);

    void depthFirstVisit(ref const(GraphT) graph,
                         VertexDescriptorT root,
                         ref VertexColourMapT vertexColourMap,
                         VisitorT visitor = VisitorT.init) {
        static struct VertexInfo {
            alias EdgeRange = typeof(graph.outEdges(VertexDescriptorT.init));
            VertexDescriptorT vertex;
            EdgeRange edges;
        }

        Stack!VertexInfo stack;

        // set up the initial point of departure
        stack.push(VertexInfo(root, graph.outEdges(root)));
        vertexColourMap[root] = Colour.Grey; 
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

                switch (vertexColourMap[v]) {
                    case Colour.White:
                        visitor.treeEdge(graph, e);
                        vertexColourMap[v] = Colour.Grey;
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

            vertexColourMap[u] = Colour.Black;
            visitor.finishVertex(graph, u);
        }
    }
}

version (unittest) {
    import std.algorithm, std.conv, std.stdio;
    import spiderpig.adjacencylist, spiderpig.traits;

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
        GraphT g;
        auto a = g.addVertex('a');
        auto b = g.addVertex('b');
        auto c = g.addVertex('c');
        auto d = g.addVertex('d');
        auto e = g.addVertex('e');
        auto f = g.addVertex('f');

        // *----------------*
        // |                |
        // |     /-> b ->\ /
        // *--> a         e -> f
        //       \-> c ->/
        //            \-> d

        g.addEdge(a, b, "a -> b"); g.addEdge(b, e, "b -> e");
        g.addEdge(a, c, "a -> c"); g.addEdge(c, e, "c -> e");
        g.addEdge(e, f, "e -> f");
        g.addEdge(e, a, "e -> a");
        g.addEdge(c, d, "c -> d");

        GraphT.VertexDescriptor[char] vertices;
        vertices = reduce!((acc, v) { acc[g[v]] = v; return acc; })(
            vertices, [a, b, c, d, e, f]);

        return TestGraph!GraphT(g, vertices);
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
    assert (discoveryOrder.length == 6,
        "Expected 6 entries in discovery order array, got " ~
        to!string(discoveryOrder.length));

    auto keyExists = delegate(char v) { return indexOf(discoveryOrder, v) >= 0; };
    
    assert (all(testGraph.vertices.keys, keyExists),
        "Expected all vertices to appear in the discovery order list");

    // Assert that the source vertex is examined
    assert (indexOf(discoveryOrder, 'a') == 0,
        "Expected Vertex A to be the first vertex discovered.");

    // Assert that the vertices are enumerated depth first
    assert (indexOf(discoveryOrder, 'f') < indexOf(discoveryOrder, 'c'), 
        "Expected vertex F to appear before vertex C.");
 
    assert (indexOf(discoveryOrder, 'f') < indexOf(discoveryOrder, 'd'), 
        "Expected vertex F to appear before vertex D.");

}
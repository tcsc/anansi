/**
 * Definitions for running a breadth-first search over a graph
 */
module spiderpig.algorithms.bfs;

import spiderpig.container, 
       spiderpig.traits,
       spiderpig.types;
import std.algorithm, 
       std.array, 
       std.stdio;

/**
 * Compile time test to check if a given type can be considered a BFS visitor
 */
template isBfsVisitor (V) {
    enum bool isBfsVisitor = is(typeof(
    (inout int = 0) {

    }));
}

/**
 * A default implementation of the breadth-first-search visitor concept that 
 * more specialised visitors can delegate the bits that they don't care about
 * to.
 */
struct NullVisitor(GraphT) {
    alias Vertex = GraphT.VertexDescriptor;
    alias Edge = GraphT.EdgeDescriptor;

    void initVertex(ref const(GraphT) g, Vertex v) {}
    void discoverVertex(ref const(GraphT) g, Vertex v) {}
    void examineVertex(ref const(GraphT) g, Vertex v) {}
    void examineEdge(ref const(GraphT) g, Edge e) {}
    void treeEdge(ref const(GraphT) g, Edge e) {}
    void nonTreeEdge(ref const(GraphT) g, Edge e) {}
    void greyTarget(ref const(GraphT) g, Edge e) {}
    void blackTarget(ref const(GraphT) g, Edge e) {}
    void finishVertex(ref const(GraphT) g, Vertex e) {}
}

/**
 * A generic breadth-first search algorithm that can be customised using a
 * visitor.
 */
template breadthFirstSearch(GraphT, 
                            VertexDescriptorT,
                            VisitorT = NullVisitor!GraphT,
                            ColourMapT = Colour[VertexDescriptorT], 
                            QueueT = FifoQueue!(VertexDescriptorT)) {

    static assert (isIncidenceGraph!GraphT);
    static assert (is(VertexDescriptorT == GraphT.VertexDescriptor));
    static assert (isPropertyMap!(ColourMapT, GraphT.VertexDescriptor, Colour));
    static assert (isBfsVisitor!VisitorT);
    static assert (isQueue!(QueueT, GraphT.VertexDescriptor));


    void breadthFirstSearch(ref const(GraphT) graph,
                            VertexDescriptorT source,
                            ref ColourMapT colourMap, 
                            VisitorT visitor = VisitorT.init,
                            QueueT queue = QueueT.init) {
        foreach(v; graph.vertices) {
            visitor.initVertex(graph, v);
            colourMap[v] = Colour.White;
        }
        BreadthFirstVisit(graph, source, colourMap, visitor, queue);
    }
}

/**
 * Breadth-first traversal of the graph from a given starting point. This 
 * function does not reset the colourMap, so can be efficiently used repeatedly 
 * on subgraphs.
 */
template BreadthFirstVisit(GraphT, 
                           VertexDescriptorT,
                           VisitorT = NullVisitor!GraphT, 
                           ColourMapT = Colour[VertexDescriptorT],
                           QueueT = FifoQueue!VertexDescriptorT) {

    static assert (isIncidenceGraph!GraphT);
    static assert (isPropertyMap!(ColourMapT, GraphT.VertexDescriptor, Colour));
    static assert (isBfsVisitor!VisitorT);
    static assert (isQueue!(QueueT, GraphT.VertexDescriptor));

    void BreadthFirstVisit(ref const(GraphT) graph,
                           VertexDescriptorT source,
                           ref ColourMapT colour, 
                           VisitorT visitor = VisitorT.init,
                           QueueT queue = QueueT.init) {
        colour[source] = Colour.Grey;
        queue.push(source);                       visitor.discoverVertex(graph, source);

        while (!queue.empty) {
            auto u = queue.front;                 visitor.examineVertex(graph, u);
            queue.pop();

            foreach (e; graph.outEdges(u)) {      visitor.examineEdge(graph, e);
                auto v = graph.target(e);
                auto c = colour[v];
                if (c == Colour.White) {          visitor.treeEdge(graph, e);
                    colour[v] = Colour.Grey;
                    queue.push(v);                visitor.discoverVertex(graph, v);
                }
                else {                            visitor.nonTreeEdge(graph, e);
                    switch (c) {
                        case Colour.Grey:         visitor.greyTarget(graph, e);
                            break;

                        case Colour.Black:        visitor.blackTarget(graph, e);
                            break;

                        default:
                            assert(false, "Unexpected colour value.");
                    }
                }
            }

            colour[u] = Colour.Black;             visitor.finishVertex(graph, u);
        }
    }
}

// ----------------------------------------------------------------------------
// Unit tests
// ----------------------------------------------------------------------------

version (unittest) {
    import std.algorithm, std.conv, std.stdio;
    import spiderpig.adjacencylist;

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

    struct TestGraph(GraphT) {
        GraphT graph;
        GraphT.VertexDescriptor[char] vertices;
    };

    TestGraph!GraphT MakeTestGraph(GraphT)() {
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

        g.addEdge(a, b); g.addEdge(b, e);
        g.addEdge(a, c); g.addEdge(c, e);
        g.addEdge(e, f);
        g.addEdge(e, a);
        g.addEdge(c, d);

        GraphT.VertexDescriptor[char] vertices;
        vertices = reduce!((acc, v) { acc[g[v]] = v; return acc; })(
            vertices, [a, b, c, d, e, f]);

        return TestGraph!GraphT(g, vertices);
    }

    alias G = AdjacencyList!(VecS, VecS, DirectedS, char, string); 
    alias Vertex = G.VertexDescriptor;
    alias Edge = G.EdgeDescriptor;
}

unittest {
    writeln("BFS: Vertices examined exactly once, and siblings examined " ~
            "before children.");

    static struct Visitor {
        this(ref G graph, ref char[] examinationOrder) {
            _graph = &graph;
            _vertexExaminationOrder = &examinationOrder;
        }

        void examineVertex(ref const(G) g, Vertex v) {
            (*_vertexExaminationOrder) ~= (*_graph)[v];
        }

        NullVisitor!G impl;
        alias impl this;

        G* _graph;
        char[]* _vertexExaminationOrder;
    }

    char[] examinationOrder;
    Colour[Vertex] colourMap;

    auto testGraph = MakeTestGraph!G(); 

    breadthFirstSearch(testGraph.graph,
                       testGraph.vertices['a'], 
                       colourMap, 
                       Visitor(testGraph.graph, examinationOrder));

    // Assert that each vertex is examined, and examined exactly once
    assert (examinationOrder.length == 6,
        "Expected 6 entries in examination order array, got " ~
        to!string(examinationOrder.length));

    auto keyExists = delegate(char v) { return indexOf(examinationOrder, v) >= 0; };
    
    assert (all(testGraph.vertices.keys, keyExists),
        "Expected all vertices to appear in the examined vertex list");

    // Assert that the source vertex is examined
    assert (indexOf(examinationOrder, 'a') == 0,
        "Expected Vertex A to be the first vertex examined.");

    // Assert that the vertices are enumerated breadth first
    assert (indexOf(examinationOrder, 'c') < indexOf(examinationOrder, 'e'), 
        "Expected vertex C to appear before vertex E.");
 
    assert (indexOf(examinationOrder, 'd') < indexOf(examinationOrder, 'f'), 
        "Expected vertex D to appear before vertex F.");
}

unittest {
    writeln("BFS: Vertices should be discovered exactly once.");

    static struct Visitor {
        this(ref int[Vertex] discoveryCounts) {
            _counts = &discoveryCounts;
        }

        void examineVertex(ref const(G) g, Vertex v) {
            (*_counts)[v]++;
        }

        NullVisitor!G impl;
        alias impl this;

        G* _graph;
        int[Vertex]* _counts;
    }

    int[Vertex] counts;
    Colour[Vertex] colourMap;

    auto testGraph = MakeTestGraph!G(); 

    breadthFirstSearch(testGraph.graph,
                       testGraph.vertices['a'], 
                       colourMap, 
                       Visitor(counts));

    // Assert that each vertex is discovered, and discovered exactly once
    assert (counts.length == 6,
        "Expected 6 entries in discovery count array, got " ~
        to!string(counts.length));

    auto pred = (Vertex v) { return (v in counts) !is null; };
    assert (all(testGraph.vertices.values, pred),
        "Every vertex must appear in the discovery count array");

    assert (std.algorithm.all!("a == 1")(counts.values));
}

unittest {
    writeln("BFS: Edges in a directed graph should be examined exactly once.");

    static struct Visitor {
        this(ref int[Edge] counts) {
            _counts = &counts;
        }

        void examineEdge(ref const(G) g, Edge e) {
            (*_counts)[e]++;
        }

        NullVisitor!G impl;
        alias impl this;

        int[Edge]* _counts;
    }

    int[Edge] counts;
    Colour[Vertex] colourMap;

    auto testGraph = MakeTestGraph!G(); 

    breadthFirstSearch(testGraph.graph,
                       testGraph.vertices['a'], 
                       colourMap, 
                       Visitor(counts));

    auto edges = Set!Edge();
    foreach (v; testGraph.graph.vertices)
        edges.insert(testGraph.graph.outEdges(v));

    // Assert that each edge is discovered, and discovered exactly once
    assert (counts.length == edges.length,
        "Expected " ~ to!string(edges.length) ~ 
        " entries in discovery count array, got " ~ to!string(counts.length));

    auto pred = (Edge e) { return (e in counts) !is null; };
    assert (all(edges, pred),
        "Every edge must appear in the discovery count array");

    assert (std.algorithm.all!("a == 1")(counts.values));
}

unittest {
    writeln("BFS: Edges in an undirected graph should be examined at least once.");
    alias UndirectedGraph = AdjacencyList!(VecS, VecS, UndirectedS, char, string); 
    alias UEdge = UndirectedGraph.EdgeDescriptor;

    static struct Visitor {
        this(ref int[UEdge] counts) {
            _counts = &counts;
        }

        void examineEdge(ref const(UndirectedGraph) g, UEdge e) {
            (*_counts)[e]++;
        }

        NullVisitor!UndirectedGraph impl;
        alias impl this;

        int[UEdge]* _counts;
    }

    auto testGraph = MakeTestGraph!UndirectedGraph(); 

    int[UEdge] counts;
    Colour[Vertex] colourMap;

    breadthFirstSearch(testGraph.graph,
                       testGraph.vertices['a'], 
                       colourMap, 
                       Visitor(counts));

    auto edges = Set!UEdge();
    foreach (v; testGraph.graph.vertices)
        edges.insert(testGraph.graph.outEdges(v));

    // Assert that each edge is discovered at least once
    assert (counts.length == edges.length,
        "Expected " ~ to!string(edges.length) ~ 
        " entries in discovery count array, got " ~ to!string(counts.length));

    auto pred = (UEdge e) { return (e in counts) !is null; };
    assert (all(edges, pred),
        "Every edge must appear in the discovery count array");

    assert (std.algorithm.all!("a > 0")(counts.values));
}

unittest {
    writeln("BFS: Tree & non-tree vertices should be identified");

    static struct Visitor {
        this(Vertex black, Vertex grey, 
             ref int treeCount,
             ref int nonTreeCount) {
            _black = black;
            _grey = grey;
            _treeEdgeCount = &treeCount;
            _nonTreeCount = &nonTreeCount;
        }

        void treeEdge(ref const(G) g, Edge e) {
            auto t = g.target(e);
            (*_treeEdgeCount)++;
        }


        void nonTreeEdge(ref const(G) g, Edge e) {
            auto t = g.target(e);
            assert (t == _black || t == _grey);
            (*_nonTreeCount)++;
        }

        void greyTarget(ref const(G) g, Edge e) {
            assert (g.target(e) == _grey);
        }

        void blackTarget(ref const(G) g, Edge e) {
            assert (g.target(e) == _black);
        }

        NullVisitor!G impl;
        alias impl this;

        Vertex _black;
        Vertex _grey;
        int* _treeEdgeCount;
        int* _nonTreeCount;
    }

    int treeCount = 0; int nonTreeCount = 0;
    Colour[Vertex] colourMap;

    auto testGraph = MakeTestGraph!G(); 

    breadthFirstSearch(testGraph.graph,
                       testGraph.vertices['a'], 
                       colourMap, 
                       Visitor(testGraph.vertices['a'],
                               testGraph.vertices['e'],
                               treeCount,
                               nonTreeCount));

    assert (treeCount == 5,
        "Expected tree hit count of 5, got " ~ to!string(nonTreeCount));

    assert (nonTreeCount == 2, 
        "Expected non-tree hit count of 2, got " ~ to!string(nonTreeCount));

}

unittest {
    writeln("BFS: Vertices should be finished exactly once.");

    static struct Visitor {
        this(ref int[Vertex] finishCounts) {
            _counts = &finishCounts;
        }

        void finishVertex(ref const(G) g, Vertex v) {
            (*_counts)[v]++;
        }

        NullVisitor!G impl;
        alias impl this;

        G* _graph;
        int[Vertex]* _counts;
    }

    int[Vertex] counts;
    Colour[Vertex] colourMap;

    auto testGraph = MakeTestGraph!G(); 

    breadthFirstSearch(testGraph.graph,
                       testGraph.vertices['a'], 
                       colourMap, 
                       Visitor(counts));

    // Assert that each vertex is discovered, and discovered exactly once
    auto vertices = array(testGraph.graph.vertices);
    assert (counts.length == vertices.length,
        "Expected " ~ to!string(vertices.length) ~ 
        " entries in edge discovery array, got " ~ to!string(counts.length));

    auto pred = (Vertex v) { return (v in counts) !is null; };
    assert (all(testGraph.vertices.values, pred),
        "Every vertex must appear in the discovery count array");

    assert (std.algorithm.all!("a == 1")(counts.values));
}
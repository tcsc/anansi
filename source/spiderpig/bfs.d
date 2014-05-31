/**
 * Definitions for running a breadth-first search over a graph
 */
module spiderpig.bfs;

import spiderpig.queue, spiderpig.traits;
import std.stdio;

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
    void greyTarget(ref const(GraphT) g, Vertex e) {}
    void blackTarget(ref const(GraphT) g, Vertex e) {}
    void finishVertex(ref const(GraphT) g, Vertex e) {}
}

enum Colour { White, Grey, Black };

/**
 * A generic breadth-first search algorithm that can be customised using a
 * visitor.
 */
template BreadthFirstSearch(GraphT, 
                            VertexDescriptorT,
                            VisitorT = NullVisitor!GraphT,
                            ColourMapT = Colour[VertexDescriptorT], 
                            QueueT = FifoQueue!(VertexDescriptorT)) {

    static assert (isIncidenceGraph!GraphT);
    static assert (is(VertexDescriptorT == GraphT.VertexDescriptor));
    static assert (isPropertyMap!(ColourMapT, GraphT.VertexDescriptor, Colour));
    static assert (isBfsVisitor!VisitorT);
    static assert (isQueue!(QueueT, GraphT.VertexDescriptor));


    void BreadthFirstSearch(ref const(GraphT) graph,
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
                if (c == Colour.White) {
                    colour[v] = Colour.Grey;
                    queue.push(v);                visitor.discoverVertex(graph, v);
                }
                else {                            visitor.nonTreeEdge(graph, e);
                    switch (c) {
                        case Colour.Grey:         visitor.greyTarget(graph, v);
                            break;

                        case Colour.Black:        visitor.blackTarget(graph, v);
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
}

unittest {
    writeln("BFS: Vertex examination order.");
    alias G = AdjacencyList!(VecS, VecS, DirectedS, char, string); 
    alias Vertex = G.VertexDescriptor;
    Vertex[] examiningOrder;

    static struct Visitor {
        this(ref Vertex[] examinationOrder) {
            _vertexExaminationOrder = &examinationOrder;
        }

        void examineVertex(ref const(G) g, Vertex v) {
            (*_vertexExaminationOrder) ~= v;
        }

        NullVisitor!G impl;
        alias impl this;
        Vertex[]* _vertexExaminationOrder;
    }

    G g;
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

    Colour[G.VertexDescriptor] colourMap;

    BreadthFirstSearch(g,
                       g.vertices().front, 
                       colourMap, 
                       Visitor(examiningOrder));

    // Assert that each vertex is examined, and examined exactly once
    assert (examiningOrder.length == 6,
        "Expected 6 entries in examination order array, got " ~
        to!string(examiningOrder.length));

    assert (
        all!(v => indexOf(examiningOrder, v) >= 0)([a, b, c, d, e, f]),
        "Expected all vertices to appear in the examined vertex list");

    // Assert that the source vertex is examined
    assert (indexOf(examiningOrder, a) == 0,
        "Expected Vertex A to be the first vertex examined.");

    // Assert that the vertices are enumerated breadth first
    assert (indexOf(examiningOrder, c) < indexOf(examiningOrder, e), 
        "Expected vertex C to appear before vertex E.");
 
    assert (indexOf(examiningOrder, d) < indexOf(examiningOrder, f), 
        "Expected vertex D to appear before vertex F.");
}
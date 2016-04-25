module anansi.algorithms.dijkstra;

import anansi.algorithms.bfs;
import anansi.algorithms.relax : relax;
import anansi.algorithms.vertex_queue : VertexQueue;
import anansi.traits;
import anansi.types;
import std.exception, std.math;

version(unittest) {
    import std.stdio;
    import anansi.adjacencylist;
}

/**
 * A default implementation of the Dijkstra visitor.
 */
struct NullDijkstraVisitor(GraphT) {
    alias Vertex = GraphT.VertexDescriptor;
    alias Edge = GraphT.EdgeDescriptor;

    void initVertex(ref const(GraphT) g, Vertex v) {}
    void discoverVertex(ref const(GraphT) g, Vertex v) {}
    void examineVertex(ref const(GraphT) g, Vertex v) {}
    void examineEdge(ref const(GraphT) g, Edge e) {}
    void edgeRelaxed(ref const(GraphT) g, Edge e) {}
    void edgeNotRelaxed(ref const(GraphT) g, Edge e) {}
    void finishVertex(ref const(GraphT) g, Vertex e) {}
}

/**
 * A BFS visitor that transforms a normal breadth-first search algoritm
 * into Dijkstra's shortest paths.
 */
package struct DijkstraBfsVisitor(GraphT,
                                  QueueT,
                                  DijkstraVisitorT,
                                  DistanceMapT,
                                  PredecessorMapT,
                                  WeightMapT) {
    alias Vertex = GraphT.VertexDescriptor;
    alias Edge = GraphT.EdgeDescriptor;

    static assert(isReadablePropertyMap!(WeightMapT, Edge, real));
    static assert(isPropertyMap!(DistanceMapT, Vertex, real));
    static assert(isPropertyMap!(PredecessorMapT, Vertex, Vertex));

    this(ref DijkstraVisitorT visitor,
         ref DistanceMapT distanceMap,
         ref const(WeightMapT) weightMap,
         ref PredecessorMapT predecessorMap,
         ref QueueT queue) {
        _visitor = &visitor;
        _distanceMap = &distanceMap;
        _weightMap = &weightMap;
        _predecessorMap = &predecessorMap;
        _queue = &queue;
    }

    /**
     * Passes the call through to the supplied Dijkstra visitor.
     */
    void initVertex(ref const(GraphT) g, Vertex v) {
        _visitor.initVertex(g, v);
    }

    void discoverVertex(ref const(GraphT) g, Vertex v) {
        _visitor.discoverVertex(g, v);
    }

    void examineVertex(ref const(GraphT) g, Vertex v) {
        _visitor.examineVertex(g, v);
    }

    void examineEdge(ref const(GraphT) g, Edge e) {
        auto weight = (*_weightMap)[e];
        enforce (weight >= 0.0);
        _visitor.examineEdge(g, e);
    }

    void treeEdge(ref const(GraphT) g, Edge e) {
        bool decreased = relax(g, *_weightMap,
                                  *_distanceMap,
                                  *_predecessorMap, e);
        if (decreased)
          _visitor.edgeRelaxed(g, e);
        else
          _visitor.edgeNotRelaxed(g, e);
    }

    void nonTreeEdge(ref const(GraphT) g, Edge e) {}

    void greyTarget(ref const(GraphT) g, Edge e) {
        const Vertex v = g.target(e);
        auto oldDistance = (*_distanceMap)[v];

        bool decreased = relax(g, *_weightMap,
                                  *_distanceMap,
                                  *_predecessorMap, e);
        if (decreased) {
            _queue.updateVertex(v);
            _visitor.edgeRelaxed(g, e);
        } else {
            _visitor.edgeNotRelaxed(g, e);
        }
    }

    void blackTarget(ref const(GraphT) g, Edge e) {}

    void finishVertex(ref const(GraphT) g, Vertex v) {
        _visitor.finishVertex(g, v);
    }

    private DijkstraVisitorT* _visitor;
    private DistanceMapT* _distanceMap;
    private const(WeightMapT*) _weightMap;
    private PredecessorMapT* _predecessorMap;
    private QueueT* _queue;
}

/**
 *
 */
template dijkstraShortestPaths(GraphT,
                               VertexDescriptorT,
                               VisitorT = NullDijkstraVisitor!GraphT,
                               WeightMapT = real[VertexDescriptorT],
                               PredecessorMapT = VertexDescriptorT[VertexDescriptorT]) {
    void dijkstraShortestPaths(ref const(GraphT) g,
                               VertexDescriptorT src,
                               ref const(WeightMapT) weights,
                               ref PredecessorMapT predecessorMap,
                               VisitorT visitor = VisitorT.init) {

        static if (is(VertexDescriptorT == size_t)) {
            auto colourMap = new Colour[g.vertexCount];
            auto distanceMap = new real[g.vertexCount];
        }
        else {
            real[VertexDescriptorT] distanceMap;
            Colour[VertexDescriptorT] colourMap;
        }

        dijkstraShortestPaths(g, src,
                              weights,
                              predecessorMap,
                              visitor,
                              colourMap,
                              distanceMap);
    }
}

/**
 *
 */
template dijkstraShortestPaths(GraphT,
                               VisitorT,
                               VertexDescriptorT,
                               ColourMapT,
                               PredecessorMapT,
                               WeightMapT,
                               DistanceMapT) {
    void dijkstraShortestPaths(ref const(GraphT) g,
                               VertexDescriptorT src,
                               ref const(WeightMapT) weights,
                               ref PredecessorMapT predecessorMap,
                               VisitorT visitor,
                               ref ColourMapT colourMap,
                               ref DistanceMapT distanceMap) {

        foreach(v; g.vertices) {
            visitor.initVertex(g, v);
            distanceMap[v] = real.infinity;
            predecessorMap[v] = v;
            colourMap[v] = Colour.White;
        }
        distanceMap[src] = 0.0;

        dijkstraShortestPathsNoInit(g, src, visitor,
                                    colourMap,
                                    weights,
                                    predecessorMap,
                                    distanceMap);
    }
}

template dijkstraShortestPathsNoInit(GraphT,
                                     VertexDescriptorT,
                                     VisitorT = NullDijkstraVisitor!GraphT,
                                     ColourMapT = Colour[VertexDescriptorT],
                                     PredecessorMapT = VertexDescriptorT[VertexDescriptorT],
                                     WeightMapT = real[VertexDescriptorT],
                                     DistanceMapT = real[VertexDescriptorT]) {
    static assert(isGraph!GraphT);

    alias EdgeDescriptorT = GraphT.EdgeDescriptor;

    static assert(isPropertyMap!(ColourMapT, VertexDescriptorT, Colour));
    static assert(isPropertyMap!(PredecessorMapT, VertexDescriptorT, VertexDescriptorT));
    static assert(isReadablePropertyMap!(WeightMapT, EdgeDescriptorT, real));
    static assert(isPropertyMap!(DistanceMapT, VertexDescriptorT, real));


    void dijkstraShortestPathsNoInit(ref const(GraphT) g,
                                     VertexDescriptorT src,
                                     VisitorT visitor,
                                     ref ColourMapT colourMap,
                                     ref const(WeightMapT) weights,
                                     ref PredecessorMapT predecessorMap,
                                     ref DistanceMapT distanceMap) {

        alias QueueT = VertexQueue!(GraphT, DistanceMapT);
        auto queue = QueueT(distanceMap);

        alias Dijkstra = DijkstraBfsVisitor!(GraphT,
                                             QueueT,
                                             VisitorT,
                                             DistanceMapT,
                                             PredecessorMapT,
                                             WeightMapT);
        breadthFirstVisit(
            g, src, colourMap,
            queue,
            Dijkstra(visitor, distanceMap, weights, predecessorMap, queue));
    }
}

version (unittest) {
    import std.array, std.algorithm, std.conv, std.stdio;
    import anansi.adjacencylist, anansi.traits, anansi.container.set;
    private alias G = AdjacencyList!(VecS, VecS, DirectedS, char, string);
    private alias Vertex = G.VertexDescriptor;
    private alias Edge = G.EdgeDescriptor;
}

unittest {
    writeln("Dijkstra: no edges shouldn't crash");
    G g;
    real[Edge] weights;
    Vertex[Vertex] predecessors;
    g.addVertex('a');
    dijkstraShortestPaths(g, g.vertices.front, weights, predecessors);
}

unittest {
    writeln("Dijkstra: shorter paths with multiple hops are preferred over long path with one hop.");

    //  / ----- 4 ----- \
    // a - 1 -> b - 1 -> c - 2 -> d
    //  \        \ ----- 5 ----- /
    //    3 -> e
    //

    G g;
    real[Edge] weights;
    Vertex[Vertex] predecessor;

    auto a = g.addVertex('a');
    auto b = g.addVertex('b');
    weights[g.addEdge(a, b, "a -> b").edge] = 1.0;

    auto c = g.addVertex('c');
    weights[g.addEdge(b, c, "b -> c").edge] = 1.0;
    weights[g.addEdge(a, c, "a -> c").edge] = 4.0;

    auto d = g.addVertex('d');
    weights[g.addEdge(c, d, "c -> d").edge] = 2.0;
    weights[g.addEdge(b, d, "b -> d").edge] = 5.0;

    auto e = g.addVertex('e');
    weights[g.addEdge(a, e, "a -> e").edge] = 3.0;


    dijkstraShortestPaths(g, g.vertices.front, weights, predecessor);

    assert(predecessor[a] == a);
    assert(predecessor[b] == a);
    assert(predecessor[c] == b);
    assert(predecessor[d] == c);
    assert(predecessor[e] == a);
}
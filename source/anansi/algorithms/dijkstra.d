module anansi.algorithms.dijkstra;

import anansi.container.priorityqueue;
import anansi.algorithms.bfs;
import anansi.traits;
import anansi.types;
import std.exception, std.math;


version(unittest) { import std.stdio; import anansi.adjacencylist; }

/**
 * A priority queue item for sorting vertices by the cost to get to them.
 */

package struct DijkstraQueue(GraphT, DistanceMapT) {
    static assert(isGraph!GraphT);
    static assert(isPropertyMap!(DistanceMapT, GraphT.VertexDescriptor, real));

    alias Vertex = GraphT.VertexDescriptor;

    package static struct Item {
        public Vertex vertex;
        public real cost;

        public int opCmp(ref const(Item) other) const { 
            return cast(int) sgn(other.cost - this.cost);
        }
    }

    this(ref const(DistanceMapT) distances) {
        _distanceMap = &distances;
    }

    public void push(Vertex v) {
        const auto distance = (*_distanceMap)[v];
        _queue.push(Item(v, distance));
    }

    public void pop() {
        _queue.pop();
    }

    public Vertex front() const  {
        return _queue.front.vertex;
    }

    public void updateVertex(Vertex v) {
        const auto distance = (*_distanceMap)[v];
        _queue.updateIf((ref Item x) => x.vertex == v, 
                        (ref Item i) => i.cost = distance);
    }

    @property public bool empty() const {
        return _queue.empty;
    }

    @property public size_t length() const {
        return _queue.length;
    } 

    PriorityQueue!Item _queue;
    const (DistanceMapT*) _distanceMap; 
}

unittest {
    writeln("Dijkstra: queue items are ordered by increasing cost.");
    alias G = AdjacencyList!();
    alias V = G.VertexDescriptor;
    alias Item = DijkstraQueue!(G, real[V]).Item;

    auto a = Item(0, 0.1);
    auto b = Item(0, 0.2);

    assert (a > b);
    assert (!(b > a));
    assert (b < a);
    assert (!(a < b));
    assert (a != b);
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
 *
 * Remark: Not every `sumFunction` works correctly.
 */
package struct DijkstraBfsVisitor(GraphT,
                                  QueueT,
                                  DijkstraVisitorT,
                                  DistanceMapT,
                                  PredecessorMapT,
                                  WeightMapT,
                                  alias sumFunction = (a, b) => a+b) {
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
        // TODO: Document the behavior of this `static if`.
        static if (__traits(compiles, (*_weightMap)[e])) {
            auto weight = (*_weightMap)[e];
        } else {
            auto weight = (*_weightMap)(e);
        }
        enforce (weight >= 0.0);
        _visitor.examineEdge(g, e);
    }

    void treeEdge(ref const(GraphT) g, Edge e) {
        bool decreased = relax(g, e);
        if (decreased)
          _visitor.edgeRelaxed(g, e);
        else
          _visitor.edgeNotRelaxed(g, e);
    }

    void nonTreeEdge(ref const(GraphT) g, Edge e) {}

    void greyTarget(ref const(GraphT) g, Edge e) {
        const Vertex v = g.target(e);
        auto oldDistance = (*_distanceMap)[v];

        bool decreased = relax(g, e);
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

    private bool relax(ref const(GraphT) g, Edge e) {
        Vertex u = g.source(e);
        Vertex v = g.target(e);
        static if (__traits(compiles, (*_weightMap)[e])) {
            const auto edgeWeight = (*_weightMap)[e];
        } else {
            const auto edgeWeight = (*_weightMap)(e);
        }
        const auto dU = (*_distanceMap)[u];
        const auto dV = (*_distanceMap)[v];

        if ((dU + edgeWeight) < dV) {
            (*_distanceMap)[v] = dU + edgeWeight;
            (*_predecessorMap)[v] = u;

            return true;
        }
        else {
            static if (GraphT.IsUndirected) {
                if ((dV + edgeWeight) < dU) {
                    (*_distanceMap)[u] = dV + edgeWeight;
                    (*_predecessorMap)[u] = v;
                    return true;
                }
            }
        }

        return false;
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
                               PredecessorMapT = VertexDescriptorT[VertexDescriptorT],
                               alias sumFunction = (a, b) => a+b) {
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
                               DistanceMapT,
                               alias sumFunction = (a, b) => a+b) {
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
                                     DistanceMapT = real[VertexDescriptorT],
                                     alias sumFunction = (a, b) => a+b) {
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

        alias QueueT = DijkstraQueue!(GraphT, DistanceMapT);
        auto queue = QueueT(distanceMap);

        alias Dijkstra = DijkstraBfsVisitor!(GraphT, 
                                             QueueT,
                                             VisitorT, 
                                             DistanceMapT,
                                             PredecessorMapT, 
                                             WeightMapT,
                                             sumFunction);
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
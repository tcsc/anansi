/**
 * Definitions for running an A* search over a graph
 */
module anansi.algorithms.astar;

import std.traits;
import std.exception;

import anansi.algorithms.bfs;
import anansi.algorithms.relax : relax;
import anansi.algorithms.vertex_queue : VertexQueue;
import anansi.types;
import anansi.traits;

version(unittest) {
    import std.stdio;
    import anansi.adjacencylist;
}

template isAStarHeuristic (CallableT, VertexT) {
    enum bool isAStarHeuristic = is(typeof(
    (ref CallableT fn, VertexT v) {
        real x = fn(v);
    }));
}

public template NullAstarVisitor(GraphT) {
    alias Vertex = GraphT.VertexDescriptor;
    alias Edge = GraphT.EdgeDescriptor;

    void initVertex(ref const(GraphT) g, Vertex v) {}
    void discoverVertex(ref const(GraphT) g, Vertex v) {}
    void examineVertex(ref const(GraphT) g, Vertex v) {}
    void examineEdge(ref const(GraphT) g, Edge e) {}
    void edgeRelaxed(ref const(GraphT) g, Edge e) {}
    void edgeNotRelaxed(ref const(GraphT) g, Edge e) {}
    void blackTarget(ref const(GraphT), Edge e) {}
    void finishVertex(ref const(GraphT) g, Vertex e) {}
}

package struct AStarBfsVisitor(GraphT,
                               QueueT,
                               AStarVisitorT,
                               DistanceMapT,
                               PredecessorMapT,
                               WeightMapT,
                               CostMapT,
                               ColourMapT,
                               HeuristicT) {
    alias Vertex = GraphT.VertexDescriptor;
    alias Edge = GraphT.EdgeDescriptor;

    static assert(isReadablePropertyMap!(WeightMapT, Edge, real));
    static assert(isPropertyMap!(DistanceMapT, Vertex, real));
    static assert(isPropertyMap!(PredecessorMapT, Vertex, Vertex));

    static assert(isCallable!HeuristicT);

this(ref AStarVisitorT visitor,
     ref DistanceMapT distanceMap,
     ref const(WeightMapT) weightMap,
     ref PredecessorMapT predecessorMap,
     ref ColourMapT colourMap,
     ref QueueT queue,
     ref CostMapT costMap,
     ref HeuristicT heuristic) {
        _visitor = &visitor;
        _distanceMap = &distanceMap;
        _weightMap = &weightMap;
        _predecessorMap = &predecessorMap;
        _queue = &queue;
        _costMap = &costMap;
        _colourMap = &colourMap;
        _heuristic = heuristic;
    }

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
        if (decreased) {
            auto t = g.target(e);
            (*_costMap)[t] = (*_distanceMap)[t] + _heuristic(t);
            _visitor.edgeRelaxed(g, e);
        } else {
            _visitor.edgeNotRelaxed(g, e);
        }
    }

    void nonTreeEdge(ref const(GraphT) g, Edge e) {

    }

    void greyTarget(ref const(GraphT) g, Edge e) {
        bool decreased = relax(g, *_weightMap,
                                  *_distanceMap,
                                  *_predecessorMap, e);
        if (decreased) {
            auto t = g.target(e);
            (*_costMap)[t] = (*_distanceMap)[t] + _heuristic(t);
            (*_queue).updateVertex(t);
            _visitor.edgeRelaxed(g, e);
        } else {
            _visitor.edgeNotRelaxed(g, e);
        }
    }

    void blackTarget(ref const(GraphT) g, Edge e) {
        bool decreased = relax(g, *_weightMap,
                                  *_distanceMap,
                                  *_predecessorMap, e);
        if (decreased) {
            auto t = g.target(e);
            _visitor.edgeRelaxed(g, e);
            (*_costMap)[t] = (*_distanceMap)[t] + _heuristic(t);
            (*_colourMap)[t] = Colour.Grey;
            _visitor.blackTarget(g, e);
        } else {
            _visitor.edgeNotRelaxed(g, e);
        }
    }

    void finishVertex(ref const(GraphT) g, Vertex e) {
        _visitor.finishVertex(g, e);
    }

    private AStarVisitorT* _visitor;
    private DistanceMapT* _distanceMap;
    private const(WeightMapT*) _weightMap;
    private PredecessorMapT* _predecessorMap;
    private QueueT* _queue;
    private ColourMapT* _colourMap;
    private CostMapT* _costMap;
    private HeuristicT _heuristic;
}

template aStarSearch(GraphT,
                     VertexDescriptorT,
                     HeuristicT,
                     VisitorT = NullAstarVisitor!GraphT,
                     WeightMapT = real[VertexDescriptorT],
                     PredecessorMapT = VertexDescriptorT[VertexDescriptorT],
                     DistanceMapT = real[VertexDescriptorT]) {
    void aStarSearch(ref const(GraphT) g,
                     VertexDescriptorT src,
                     HeuristicT heuristic,
                     ref const (WeightMapT) weights,
                     ref PredecessorMapT predecessorMap,
                     VisitorT visitor = VisitorT.init) {
        static if (is(VertexDescriptorT == size_t)) {
            auto colourMap = new Colour[g.vertexCount];
            auto distanceMap = new real[g.vertexCount];
            auto costMap = new real[g.vertexCount];
        }
        else {
            real[VertexDescriptorT] distanceMap;
            real[VertexDescriptorT] costMap;
            Colour[VertexDescriptorT] colourMap;
        }

        aStarSearch(g,
                    src,
                    heuristic,
                    weights,
                    predecessorMap,
                    visitor,
                    colourMap,
                    distanceMap,
                    costMap);
    }
}

template aStarSearch(GraphT,
                     VertexDescriptorT,
                     HeuristicT,
                     VisitorT = NullAstarVisitor!GraphT,
                     ColourMapT = Colour[VertexDescriptorT],
                     PredecessorMapT = VertexDescriptorT[VertexDescriptorT],
                     WeightMapT = real[VertexDescriptorT],
                     DistanceMapT = real[VertexDescriptorT],
                     CostMapT = real[VertexDescriptorT]) {
    void aStarSearch(ref const(GraphT) g,
                     VertexDescriptorT src,
                     HeuristicT heuristic,
                     ref const(WeightMapT) weights,
                     ref PredecessorMapT predecessorMap,
                     VisitorT visitor,
                     ref ColourMapT colourMap,
                     ref DistanceMapT distanceMap,
                     ref CostMapT costMap) {
        foreach(v; g.vertices) {
            visitor.initVertex(g, v);
            distanceMap[v] = real.infinity;
            costMap[v] = real.infinity;
            predecessorMap[v] = v;
            colourMap[v] = Colour.White;
        }
        distanceMap[src] = 0.0;

        aStarSearchNoInit(g,
                          src,
                          heuristic,
                          weights,
                          predecessorMap,
                          visitor,
                          colourMap,
                          distanceMap,
                          costMap);
    }
}

template aStarSearchNoInit(GraphT,
                           VertexDescriptorT,
                           HeuristicT,
                           VisitorT = NullAstarVisitor!GraphT,
                           ColourMapT = Colour[VertexDescriptorT],
                           PredecessorMapT = VertexDescriptorT[VertexDescriptorT],
                           WeightMapT = real[VertexDescriptorT],
                           DistanceMapT = real[VertexDescriptorT],
                           CostMapT = real[VertexDescriptorT]) {
    static assert(isGraph!GraphT);

    alias EdgeDescriptorT = GraphT.EdgeDescriptor;

    static assert(isPropertyMap!(ColourMapT, VertexDescriptorT, Colour));
    static assert(isPropertyMap!(PredecessorMapT, VertexDescriptorT, VertexDescriptorT));
    static assert(isReadablePropertyMap!(WeightMapT, EdgeDescriptorT, real));
    static assert(isPropertyMap!(CostMapT, VertexDescriptorT, real));

    static assert(isCallable!HeuristicT);


    void aStarSearchNoInit(ref const(GraphT) g,
                           VertexDescriptorT src,
                           HeuristicT heuristic,
                           ref const(WeightMapT) weights,
                           ref PredecessorMapT predecessorMap,
                           VisitorT visitor,
                           ref ColourMapT colourMap,
                           ref DistanceMapT distanceMap,
                           ref CostMapT costMap) {
        alias QueueT = VertexQueue!(GraphT, CostMapT);
        auto queue = QueueT(costMap);

        alias AStar = AStarBfsVisitor!(GraphT,
                                       QueueT,
                                       VisitorT,
                                       DistanceMapT,
                                       PredecessorMapT,
                                       WeightMapT,
                                       CostMapT,
                                       ColourMapT,
                                       HeuristicT);
        auto astar = AStar(visitor,
                           distanceMap,
                           weights,
                           predecessorMap,
                           colourMap,
                           queue,
                           costMap,
                           heuristic);
        breadthFirstVisit(g, src, colourMap, queue, astar);
    }
}

template extractPath(VertexDescriptorT,
                     PredecessorMapT = VertexDescriptorT[VertexDescriptorT],
                     
) {
    import std.algorithm : reverse;
    import std.container : Array;

    static assert(isPropertyMap!(PredecessorMapT, VertexDescriptorT, VertexDescriptorT));

    Array!VertexDescriptorT extractPath(ref PredecessorMapT predecessorMap,
                                        VertexDescriptorT dst) {
        auto path = Array!VertexDescriptorT();
        auto v = dst;
        while (true) {
            path.insertBack(v);
            auto prev = predecessorMap[v];
            if (prev == v) {
                break;
            }
            v = prev;
        }
        reverse(path[]);
        return path;
    }
}

version(unittest) {
    import std.algorithm : reverse;
    import std.container : Array;

    private struct Node {
        char id;
        int weight;
    };

    private struct TestGraph(GraphT) {
        GraphT graph;
        GraphT.VertexDescriptor[char] vertices;

        alias graph this;

        GraphT.VertexDescriptor opIndex(char id) {
            return vertices[id];
        }
    };

    private TestGraph!GraphT MakeTestGraph(GraphT)() {
        // Test data from: 
        //  https://www.slideshare.net/hemak15/lecture-14-heuristic-searcha-star-algorithm
        GraphT graph;
        auto s = graph.addVertex(Node('s', 17));
        auto a = graph.addVertex(Node('a', 10));
        auto b = graph.addVertex(Node('b', 13));
        auto c = graph.addVertex(Node('c',  4));
        auto d = graph.addVertex(Node('d',  2));
        auto e = graph.addVertex(Node('e',  4));
        auto f = graph.addVertex(Node('f',  1));
        auto g = graph.addVertex(Node('g',  0));
        auto h = graph.addVertex(Node('h', 99));

        //     /-> a 
        //    /     \
        //   /       e     h 
        //  /       / \
        // s ----> b   f -> g  
        //  \       \ /
        //   \       d
        //    \     /
        //     \-> c

        graph.addEdge(s, a,  6);
        graph.addEdge(s, b,  5);
        graph.addEdge(s, c, 10);
        graph.addEdge(a, e,  6);
        graph.addEdge(b, e,  6);
        graph.addEdge(c, d,  6);
        graph.addEdge(b, d,  7);
        graph.addEdge(d, f,  6);
        graph.addEdge(e, f,  4);
        graph.addEdge(f, g,  3);

        GraphT.VertexDescriptor[char] vertices;
        foreach (v; graph.vertices()) {
            vertices[graph[v].id] = v;
        }
        return TestGraph!GraphT(graph, vertices);
    }

    private alias G = AdjacencyList!(VecS, VecS, DirectedS, Node, int); 
    private alias Vertex = G.VertexDescriptor;
    private alias Edge = G.EdgeDescriptor;

    class FoundTarget : Throwable {
        this() { super("found it"); }
    }

    struct Visitor {
        mixin NullAstarVisitor!G;

        Vertex _target;

        this(Vertex target) {
            _target = target;
        }        

        void examineVertex(ref const(G) g, Vertex v) {
            if (v == _target) {
                throw new FoundTarget;
            }
        }
    }
}

unittest {
    writeln("A*: Finds a path");

    auto testGraph = MakeTestGraph!G();
    auto predecessors = new Vertex[testGraph.vertexCount];

    auto start = testGraph['s'];
    auto destination = testGraph['g'];

    real heuristic(Vertex v) { return testGraph.graph[v].weight; }

    try {
        aStarSearch(testGraph,
                    start,
                    &heuristic,
                    testGraph.graph,
                    predecessors,
                    Visitor(destination));
        assert (false, "Path not found");
    }
    catch(FoundTarget) {
    }
    auto path = extractPath(predecessors, destination);
    auto v = testGraph.vertices;
    const auto expectedPath = Array!Vertex([v['s'], v['b'], v['e'], v['f'], v['g']]);
    assert (path == expectedPath);
}

unittest {
    writeln("A*: Terminates on unreachable node");

    auto testGraph = MakeTestGraph!G();
    auto g = &testGraph.graph;
    auto predecessor = new Vertex[g.vertexCount];

    auto start = testGraph.vertices['s'];
    auto destination = testGraph.vertices['h'];

    real heuristic(Vertex v) { return (*g)[v].weight; }
    try {
        aStarSearch(*g,
                    start,
                    &heuristic,
                    *g,
                    predecessor,
                    Visitor(destination));
    }
    catch(FoundTarget) {
        assert (false, "Should never find an answer");
    }
}
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

struct NullAstarVisitor(GraphT) {
    alias Vertex = GraphT.VertexDescriptor;
    alias Edge = GraphT.EdgeDescriptor;

    void initVertex(ref const(GraphT) g, Vertex v) {}
    void discoverVertex(ref const(GraphT) g, Vertex v) {}
    void examineVertex(ref const(GraphT) g, Vertex v) {}
    void examineEdge(ref const(GraphT) g, Edge e) {}
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
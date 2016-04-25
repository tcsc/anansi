module anansi.algorithms.relax;
import anansi.traits;
import anansi.types;

package template relax(GraphT, WeightMapT, DistanceMapT, PredecessorMapT, EdgeT) {
    alias VertexT = GraphT.VertexDescriptor;

    static assert(isReadablePropertyMap!(WeightMapT, EdgeT, real));
    static assert(isPropertyMap!(DistanceMapT, VertexT, real));
    static assert(isPropertyMap!(PredecessorMapT, VertexT, VertexT));
    static assert(is(EdgeT == GraphT.EdgeDescriptor));

    bool relax(ref const(GraphT) g,
               ref const(WeightMapT) weightMap,
               ref DistanceMapT distanceMap,
               ref PredecessorMapT predecessorMap,
               EdgeT e) {
        VertexT u = g.source(e);
        VertexT v = g.target(e);

        const auto edgeWeight = weightMap[e];
        const auto dU = distanceMap[u];
        const auto dV = distanceMap[v];

        if ((dU + edgeWeight) < dV) {
            distanceMap[v] = dU + edgeWeight;
            predecessorMap[v] = u;
            return true;
        }
        else {
            static if (GraphT.IsUndirected) {
                if ((dV + edgeWeight) < dU) {
                    distanceMap[u] = dV + edgeWeight;
                    predecessorMap[u] = v;
                    return true;
                }
            }
        }
        return false;
    }
}
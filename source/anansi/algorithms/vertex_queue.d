module anansi.algorithms.vertex_queue;

import anansi.container.priorityqueue;
import anansi.traits;
import anansi.types;
import std.math;

version(unittest) { import std.stdio; import anansi.adjacencylist; }


/**
 * A priority queue item for sorting vertices by the cost to get to them.
 */

package struct VertexQueue(GraphT, DistanceMapT) {
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
    writeln("VertexQueue: queue items are ordered by increasing cost.");
    alias G = AdjacencyList!();
    alias V = G.VertexDescriptor;
    alias Item = VertexQueue!(G, real[V]).Item;

    auto a = Item(0, 0.1);
    auto b = Item(0, 0.2);

    assert (a > b);
    assert (!(b > a));
    assert (b < a);
    assert (!(a < b));
    assert (a != b);
}
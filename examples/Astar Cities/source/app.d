/**
 * An example using the anansi A* search algorithm. Ported from the
 * boost graph library's example.
 */
import anansi,
       anansi.algorithms.astar;
import std.math : sqrt;
import std.stdio : writeln;

struct City {
    this(string n, real latitude, real longitude) {
        name = n;
        lat = latitude;
        lng = longitude;
    }

    string name;
    real lat;
    real lng;
}

alias Graph = AdjacencyList!(VecS, VecS, DirectedS, City, real);
alias Vertex = Graph.VertexDescriptor;

class FoundTarget : Throwable {
    this() { super("found it"); }
}

struct AStarGoalVisitor {
    alias Vertex = Graph.VertexDescriptor;
    alias Edge = Graph.EdgeDescriptor;

    this(Vertex target) {
        _target = target;
    }

    void initVertex(ref const(Graph) g, Vertex v) {}
    void discoverVertex(ref const(Graph) g, Vertex v) {}
    void examineEdge(ref const(Graph) g, Edge e) {}
    void edgeRelaxed(ref const(Graph) g, Edge e) {}
    void edgeNotRelaxed(ref const(Graph) g, Edge e) {}
    void blackTarget(ref const(Graph), Edge e) {}
    void finishVertex(ref const(Graph) g, Vertex e) {}

    void examineVertex(ref const(Graph) g, Vertex v) {
        if (v == _target) {
            throw new FoundTarget;
        }
    }

    Vertex _target;
}


void main() {
    Graph g;

    auto troy          = g.addVertex(City("Troy",          42.73, 73.68));
    auto lake_placid   = g.addVertex(City("Lake Placid",   44.28, 73.99));
    auto plattsborough = g.addVertex(City("Plattsborough", 44.70, 73.46));
    auto massena       = g.addVertex(City("Massena",       44.93, 74.89));
    auto watertown     = g.addVertex(City("Watertown",     43.97, 75.91));
    auto utica         = g.addVertex(City("Utica",         43.10, 75.23));
    auto syracuse      = g.addVertex(City("Syracuse",      43.04, 76.14));
    auto rochester     = g.addVertex(City("Rochester",     43.17, 77.61));
    auto buffalo       = g.addVertex(City("Buffalo",       42.89, 78.86));
    auto ithaca        = g.addVertex(City("Ithaca",        42.44, 76.50));
    auto binghamton    = g.addVertex(City("Binghamon",     42.10, 75.91));
    auto woodstock     = g.addVertex(City("Woodstock",     42.04, 74.11));
    auto new_york      = g.addVertex(City("New York",      40.67, 73.94));

    g.addEdge(troy,          utica,          93);
    g.addEdge(troy,          lake_placid,   134);
    g.addEdge(troy,          plattsborough, 143);
    g.addEdge(lake_placid,   plattsborough,  65);
    g.addEdge(plattsborough, massena,       115);
    g.addEdge(lake_placid,   massena,       113);
    g.addEdge(massena,       watertown,     117);
    g.addEdge(watertown,     utica,         116);
    g.addEdge(watertown,     syracuse,       74);
    g.addEdge(utica,         syracuse,       56);
    g.addEdge(syracuse,      rochester,      84);
    g.addEdge(rochester,     buffalo,        73);
    g.addEdge(syracuse,      ithaca,         69);
    g.addEdge(ithaca,        binghamton,     70);
    g.addEdge(ithaca,        rochester,     116);
    g.addEdge(binghamton,    troy,          147);
    g.addEdge(binghamton,    woodstock,     173);
    g.addEdge(binghamton,    new_york,      183);
    g.addEdge(syracuse,      binghamton,     74);
    g.addEdge(woodstock,     troy,           71);
    g.addEdge(woodstock,     new_york,      124);

    auto src = woodstock;
    auto target = watertown;

    real heuristic(Vertex v) {
        auto dx = g[target].lng - g[v].lng;
        auto dy = g[target].lat - g[v].lat;
        return sqrt(dx * dx + dy * dy);
    }

    auto predecessor = new Graph.VertexDescriptor[g.vertexCount];

    try {
        aStarSearch(g,
                    src,
                    &heuristic,
                    g,
                    predecessor,
                    AStarGoalVisitor(target));
    }
    catch(FoundTarget) {
        writeln("Found a path");
    }
}
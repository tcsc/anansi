/**
 * An example using the anansi connected compomemt finder. Ported from the 
 * boost graph library's example.
 */

import std.stdio;
import anansi, anansi.algorithms;

void main() {
    alias G = AdjacencyList!(VecS, VecS, UndirectedS, char);
    G graph;
    auto a = graph.addVertex('a');
    auto b = graph.addVertex('b');
    auto c = graph.addVertex('c');
    auto d = graph.addVertex('d');
    auto e = graph.addVertex('e');
    auto f = graph.addVertex('f');

    graph.addEdge(a, b);
    graph.addEdge(b, e);
    graph.addEdge(e, a);
    graph.addEdge(c, f);
    
    size_t[6] componentMap;
    auto nComponents = connectedComponents(graph, componentMap);

    writeln("Total number of components: ", nComponents);
    foreach(v; graph.vertices) {
        writeln("Vertex ", graph[v], " is in component ", componentMap[v]);
    }
}

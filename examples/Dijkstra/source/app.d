
/**
 * Copyright 2014 Trent Clarke.
 * 
 * Distributed under the Boost Software License, Version 1.0. (See
 * copy at http://www.boost.org/LICENSE_1_0.txt)
 */

import anansi, anansi.algorithms.dijkstra;
import std.stdio;

void main()
{
	alias Graph = AdjacencyList!(VecS, VecS, DirectedS, char, string);
	
	Graph graph;
	auto a = graph.addVertex('a');
    auto b = graph.addVertex('b');
    auto c = graph.addVertex('c');
    auto d = graph.addVertex('d');
    auto e = graph.addVertex('e');

    real[Graph.EdgeDescriptor] weight;

    weight[graph.addEdge(a, c, "a -> c").edge] = 1;
    weight[graph.addEdge(b, b, "b -> b").edge] = 2;
    weight[graph.addEdge(b, d, "b -> d").edge] = 1;
    weight[graph.addEdge(b, e, "b -> e").edge] = 2;
    weight[graph.addEdge(c, b, "c -> b").edge] = 7;
    weight[graph.addEdge(c, d, "c -> d").edge] = 3;
    weight[graph.addEdge(d, e, "d -> e").edge] = 1;
	weight[graph.addEdge(e, a, "e -> a").edge] = 1;
	weight[graph.addEdge(e, b, "e -> b").edge] = 1;

	auto colourMap = new Colour[graph.vertexCount];
	auto distance = new real[graph.vertexCount];
	auto predecessor = new Graph.VertexDescriptor[graph.vertexCount];
	dijkstraShortestPaths(graph, a, weight, predecessor, 
						  NullDijkstraVisitor!Graph(), 
						  colourMap,
						  distance);


	foreach(v; graph.vertices) {
		writeln(graph[v], " - Distance: ", distance[v], 
						  ", Predecessor: ", graph[predecessor[v]]);
	}
}

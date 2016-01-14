module anansi.algorithms.components;

import std.stdio, std.meta;

import anansi.algorithms.dfs,
       anansi.traits,
       anansi.types;

/**
 * Lists the connected components (a.k.a "islands") of an undirected graph.
 *
 * Params:
 *   GraphT = The type of the graph object to examine. Must model the
 *            incidence graph concept and be undirected.
 *   ComponentMapT = The type of the component map to use. Must model a 
 *                   property map of ints keyed by GraphT vertex 
 *                   descriptor. 
 */
template connectedComponents(GraphT, ComponentMapT) {
    static assert (isGraph!GraphT);
    static assert (GraphT.IsUndirected);
    static assert (isPropertyMap!(ComponentMapT, GraphT.VertexDescriptor, size_t));

    /**
     * Params:
     *   g = The graph to examine.
     *   components = The component map to populate.
     *
     * Returns: 
     *   Returns the number of components in the graph.
     */
    size_t connectedComponents(ref const(GraphT) g, ref ComponentMapT components) {
        alias Vertex = GraphT.VertexDescriptor;
        alias Edge = GraphT.EdgeDescriptor;

        static struct ComponentRecorder {
            this(ref size_t count, ref ComponentMapT componentMap) {
                _group = &count;
                _components = &componentMap;
            }

            void startVertex(ref const(GraphT), Vertex v) {
                if( (*_group) == size_t.max )
                    (*_group) = 0;
                else
                    (*_group)++;
            }

            void discoverVertex(ref const(GraphT), Vertex v) {
                (*_components)[v] = (*_group);
            }

            private size_t* _group; 
            private ComponentMapT* _components;

            NullVisitor!GraphT impl;
            alias impl this;
        } 

        if( g.vertices.empty )
            return 0;

        // Let's try and represent the colour map as an array if we can; it'll
        // make map access stupidly fast. 
        static if (is(Vertex == size_t)) {
            auto colourMap = new Colour[g.vertexCount];
        }
        else {
            Colour[Vertex] colourMap;
        }

        size_t count = size_t.max;
        depthFirstSearch(g, g.vertices.front, colourMap, 
                         ComponentRecorder(count, components));
        return count+1;
    }
}

// ----------------------------------------------------------------------------
//
// ----------------------------------------------------------------------------

version (unittest) {
    import std.algorithm, std.conv, std.stdio;
    import anansi.adjacencylist, anansi.traits;

    void makeDisconnectedCycles(G)(ref G g, int cycles, int cycleSize) {
        alias Vertex = G.VertexDescriptor;
        foreach(i; 0 .. cycles) {
            Vertex firstVertex = g.addVertex();
            Vertex prevVertex;
            Vertex currentVertex = firstVertex;
            foreach(j; 1 .. cycleSize) {
                prevVertex = currentVertex;
                currentVertex = g.addVertex();
                g.addEdge(prevVertex, currentVertex);
            }
            g.addEdge(currentVertex, firstVertex);
        }
    }
}

unittest {
    writeln("Connected Components: Empty graph should return 0.");
    alias G = AdjacencyList!(VecS, VecS, UndirectedS);
    G g;
    size_t[G.VertexDescriptor] components;
    auto rval = connectedComponents(g, components);

    assert (rval == 0, 
        "connectedComponents() should return 0 for an empty graph.");

    assert (components.length == 0,
        "connected components array should be 0 length.");
}


unittest {
    writeln("Connected Components: Components should be identified.");
    // check each supported configuration of storage selectors 
    foreach(VertexStorage; AliasSeq!(VecS, ListS)) {
        foreach(EdgeStorage; AliasSeq!(VecS, ListS)) {
            alias G = AdjacencyList!(VertexStorage, EdgeStorage, UndirectedS);
            G g;
            size_t[G.VertexDescriptor] components;
            makeDisconnectedCycles(g, 5, 10);
            auto rval = connectedComponents(g, components);

            assert (rval == 5, 
                "connectedComponents should return the number of components discovered.");

            int[size_t] tally;
            foreach(k, v; components) { tally[v]++; }

            assert( all!("a == 10")(tally.values), 
                "All components should have size 10." );
        }
    }
}

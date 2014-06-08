module anansi.algorithms.components;

import std.stdio;

import anansi.algorithms.dfs,
       anansi.traits,
       anansi.types;

template connectedComponents(GraphT, ComponentMapT) {
    static assert (isGraph!GraphT);
    static assert (isPropertyMap!(ComponentMapT, 
        GraphT.VertexDescriptor, size_t));


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
        depthFirstSearch(g, g.vertices[0], colourMap, 
                         ComponentRecorder(count, components));
        return count+1;
    }
}
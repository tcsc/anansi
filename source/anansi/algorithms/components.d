module anansi.algorithms.components;

import anansi.algorithms.dfs,
       anansi.traits;

template connectedComponents(GraphT, ComponentMapT) {
    static assert (isGraph!GraphT);
    static assert (isPropertyMap!(ComponentMapT, 
        GraphT.VertexDescriptor, size_t));

    alias Vertex = GraphT.VertexDescriptor;
    alias Edge = GraphT.EdgeDescriptor;

    size_t connectedComponents(ref const(GraphT) graph) {
        static struct ComponentRecorder {
            this(ref size_t count, ref ComponentMapT componentMap) {
                _count = &count;
                _components = &componentMap;
            }

            void startVertex(ref const(GraphT), Vertex v) {
                if( (*_count) == size_t.max )
                    (*_count) == 0;
                else
                    (*_count)++;
            }

            void discoverVertex(ref const(GraphT), Vertex v) {
                (*_components)[v] = (*_count);
            }

            private size_t* _count; 
            private ComponentMapT* _components;

            NullVisitor!GraphT impl;
            alias impl this;
        } 
    }
}
/**
 * Implements depth-first search over graphs.
 */
module spiderpig.algorithms.dfs;

import spiderpig.types;

/**
 * Compile time test to check if a given type can be considered a DFS visitor.
 */
template isBfsVisitor (V) {
    enum bool isBfsVisitor = is(typeof(
    (inout int = 0) {

    }));
}


/**
 * A default implementation of the depth-first-search visitor concept that 
 * more specialised visitors can delegate the bits that they don't care about
 * to.
 */
struct NullVisitor(GraphT) {
    alias Vertex = GraphT.VertexDescriptor;
    alias Edge = GraphT.EdgeDescriptor;

    void initVertex(ref const(GraphT) g, Vertex v) {};
    void startVertex(ref const(GraphT) g, Vertex v) {};
    void discoverVertex(ref const(GraphT) g, Vertex v) {};
    void examineEdge(ref const(GraphT) g, Edge e) {};
    void treeEdge(ref const(GraphT) g, Edge e) {};
    void backEdge(ref const(GraphT) g, Edge e) {};
    void forwardOrCrossEdge(ref const(GraphT) g, Edge e) {};
    void finishVertex(ref const(GraphT) g, Vertex e) {};
}

template depthFirstSearch(GraphT, 
                          VertexDescriptorT,
                          EdgeDescriptorT,
                          VisitorT = NullVisitor!GraphT,
                          VertexColourMapT = Colour[VertexDescriptorT],
                          EdgeColourMapT = Colour[EdgeDescriptorT]) {

    static assert (isIncidenceGraph!GraphT);
    static assert (is(VertexDescriptorT == GraphT.VertexDescriptor));
    static assert (is(EdgeDescriptorT == GraphT.EdgeDescriptor));
    static assert (isPropertyMap!(VertexColourMapT, GraphT.VertexDescriptor, Colour));
    static assert (isPropertyMap!(EdgeColourMapT, GraphT.VertexDescriptor, Colour));
    static assert (isDfsVisitor!VisitorT);

    void depthFirstSearch(ref const(GraphT) graph,
                          VertexDescriptorT root,
                          ref VertexColourMapT vertexColourMap,
                          ref EdgeColourMapT edgeColourMap,
                          VisitorT visitor = VisitorT.init) {
        foreach(v; graph.vertices()) {
            vertexColourMap[v] = Colour.White;
            visitor.initVertex(graph, v);
        }

//        foreach(e; graph.edges)
//            edgeColourMap[e] = Colour.White;

        depthFirstVisit(graph, root, vertexColourMap, edgeColourMap, visitor);

        foreach(v; graph.vertices()) {
            if (vertexColourMap[v] == Colour.White) {
                depthFirstVisit(graph, root, vertexColourMap, edgeColourMap, visitor);
            }
        }
    }
}

template depthFirstVisit(GraphT,
                         VertexDescriptorT,
                         EdgeDescriptorT,
                         VisitorT = NullVisitor!GraphT,
                         VertexColourMapT = Colour[VertexDescriptorT],
                         EdgeColourMapT = Colour[EdgeDescriptorT]) {

    static assert (isIncidenceGraph!GraphT);
    static assert (is(VertexDescriptorT == GraphT.VertexDescriptor));
    static assert (is(EdgeDescriptorT == GraphT.EdgeDescriptor));
    static assert (isPropertyMap!(VertexColourMapT, GraphT.VertexDescriptor, Colour));
    static assert (isPropertyMap!(EdgeColourMapT, GraphT.VertexDescriptor, Colour));
    static assert (isDfsVisitor!VisitorT);

    void depthFirstVisit(ref const(GraphT) graph,
                         VertexDescriptorT root,
                         ref VertexColourMapT vertexColourMap,
                         ref EdgeColourMapT edgeColourMap,
                         VisitorT visitor = VisitorT.init) {
        vertexColourMap[root] = Colour.Grey; visitor.discoverVertex(graph, root);
        foreach(e; graph.outEdges()) {

        }
    }
}
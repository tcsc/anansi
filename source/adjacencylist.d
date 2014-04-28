import std.traits,
       std.typecons;
import container, traits;

struct AdjacencyList (VertexStorage = ArrayS,
                      EdgeStorage = ArrayS,
                      Directionality = DirectedS,
                      VertexProperty = NoProperty,
                      EdgeProperty = NoProperty)
    if( isSelector!VertexStorage && 
        isSelector!EdgeStorage && 
        isDirectionality!Directionality)
{
private:
    static if (is(VertexStorage == ArrayS)) {
        alias VertexDescriptor = size_t;
    }
    else {
        alias VertexDescriptor = void*;
    }

    struct Edge {
        VertexDescriptor src;
        VertexDescriptor dst;
        static if (is(EdgeProperty != NoProperty)) {
            EdgeProperty*  property;
        }
    }

    struct Vertex {
    private:
        (Edge*)[] _outEdges;

        static if (!is(Directionality == BidirectionalS)) {
            (Edge*)[] _inEdges;
        }

        static if (!is(VertexProperty == NoProperty)) {
            VertexProperty property;
        }
    }

    static if (is(VertexStorage == ArrayS)) {
        Vertex[] _vertices;
    }
    else {
        DList!Vertex _vertices;
    }
}

struct AdjacencyVector(VertexProperty, 
                       EdgeProperty, 
                       Directionality = UndirectedS,
                       EdgeStorageClass = ArrayS)
    if (isSelector!EdgeStorageClass)
{
public:
    alias VertexDescriptor = size_t;
    alias EdgeDescriptor = Tuple!(VertexDescriptor, "src", int, "index");

private:
    enum IsBidirectional = is(Directionality : BidirectionalS);
    enum IsUndirected = is(Directionality : UndirectedS);

    class EdgePropertyWrapper {
        EdgeProperty _payload;        
    }

    static struct Edge {
        VertexDescriptor _otherEnd;
        EdgePropertyWrapper _property;
    }

    static if (is(EdgeStorageClass : ArrayS)) {
        alias EdgeList = Array!Edge;
        alias EdgeListIndex = size_t;
    }
    else static if (is(EdgeStorageClass : ListS)) {
        alias EdgeList = DList!Edge;
        alias EdgeListIndex = DList!(Edge).Range;
    }

    static struct Vertex {
        this(VertexProperty property) { _property = property; }

        this(this) {
            _outEdges = this._outEdges.dup();
            static if(is(Directionality : BidirectionalS)) {
                _inEdges = this._inEdges.dup();
            }
        }

        VertexProperty _property;
        EdgeList _outEdges;

        EdgeListIndex addOutEdge(VertexDescriptor dst, 
                                 EdgePropertyWrapper p) {
            return addEdgeImpl(_outEdges, dst, p);
        }

        ref inout(Edge) outEdge(EdgeListIndex i) inout {
            return getEdgeImpl(_outEdges, i);
        }

        static if(is(Directionality : BidirectionalS)) {
            EdgeList _inEdges;

            EdgeListIndex addInEdge(VertexDescriptor src,
                                    EdgePropertyWrapper p) {
                return addEdgeImpl(_inEdges, src, p);
            }

            ref inout(EdgeProperty) inEdge(EdgeListIndex index) inout {
                return getEdgeImpl(_inEdges, index);
            }
        }

    private:
        EdgeListIndex addEdgeImpl(ref EdgeList edgeList, 
                                  VertexDescriptor otherEnd,
                                  EdgePropertyWrapper p) {
            edgeList.insertBack(Edge(otherEnd, p));
            static if (is(EdgeStorageClass == ArrayS)) {
                return edgeList.length;
            }
            else static if (is(EdgeStorageClass == ListS)) {
                return ListS[$..];
            }
        }

        ref inout(Edge) getEdgeImpl(ref inout(EdgeList) edges, 
                                    EdgeListIndex i) {
            static if (is(EdgeStorageClass == ArrayS)) {
                return edges[i];
            }
            else static if (is(EdgeStorageClass == ListS)) {
                return i.front;
            }
        }
    }

    private Vertex[] _vertices;
    private size_t _size;
    private DList!EdgeProperty _edgeProperties;

    // ------------------------------------------------------------------------
    // Vertex manipulation
    // ------------------------------------------------------------------------

public:
    @property size_t vertexCount() const {
        return _vertices.length;
    }

    VertexDescriptor addVertex(VertexProperty property) {
        if ((_size + 1) > _vertices.length )
            reserve(1 + (_size * 3 / 2));
        immutable VertexDescriptor result = _size++;
        _vertices[result] = Vertex(property);
        return result;
    }

    EdgeDescriptor addEdge(VertexDescriptor src, 
                           VertexDescriptor dst, 
                           EdgeProperty property) 
    in {
        assert(src < _size);
        assert(dst < _size);
    }
    body {
        static if(IsUndirected) {
            s = min(src, dst);
            d = max(src, dst);
            src = s;
            dst = d;
        }

        _edgeProperties.insertBack(property);
        EdgeProperty* propertyRef = &
        _vertices[src].addOutEdge(dst, propertyRef);
        static if (IsBidirectional) {
            _vertices[dst].addInEdge(src, propertyRef);
        }
    }

    /**
     * Returns a (possibly const) reference to a vertex property.
     */
    ref inout(VertexProperty) opIndex(VertexDescriptor v) inout
    in {
        assert(v < _size);
    }
    body {
        return _vertices[v]._property;
    }

    ref inout(EdgeProperty) opIndex(EdgeDescriptor e) inout {
        Vertex* src = &_vertices[e.src];
        return src.outEdge(e.index);
    }

    VertexDescriptor Source(EdgeDescriptor edge) {
        return edge.src;
    }

    VertexDescriptor Source(EdgeDescriptor edge) {
        return edge.src;
    }

private:
    void reserve(size_t n) {
        if (n > _vertices.length) {
            _vertices.length = n;            
        }
    }
}

version (unittest) {
    void ForEachStorageClass(Directionality, string code)() {
        foreach (OutEdgeStorageClass; TypeTuple!(ArrayS, ListS)) {
            foreach (InEdgeStorageClass; TypeTuple!(ArrayS, ListS)) {
                alias Graph = AdjacencyVector!(char, char, 
                                               Directionality, 
                                               VertexStorageClass,
                                               OutEdgeStorageClass, 
                                               InEdgeStorageClass);
                static assert(isGraph!Graph);
                Graph g;
                mixin(code);
            }
        }
    }

    void InitialConditions(G)(ref G g) {
        assert(g.vertexCount == 0);
    }
}

unittest {
    AdjacencyVector!(char, string, DirectedS, ArrayS) graph;

    //foreach (Directionality; TypeTuple!(DirectedS, UndirectedS, BidirectionalS)) {
    //    ForEachStorageClass!(Directionality, "InitialConditions(g);")();
    //}
    //foreach (VertexStorageClass; TypeTuple!(ArrayS, ListS)) {
    //    foreach (EdgeStorageClass; TypeTuple!(ArrayS, ListS)) {
    //        foreach (Directionality; TypeTuple!(DirectedS, UndirectedS, BidirectionalS)) {
    //            alias Graph = AdjacencyList!(char, char, 
    //                                         Directionality, 
    //                                         VertexStorageClass,
    //                                         EdgeStorageClass, 
    //                                         EdgeStorageClass);
    //            static assert(isGraph!Graph);
    //        }
    //    }
    //}
}

//unittest {
//    auto storageClasses = TypeTuple!(ArrayS, ListS);
//    foreach (vertexStorageClass; storageClasses) {
//        foreach (edgeStorageClass; storageClasses) {
//            alias Graph = AdjacencyList!(char, char, Class.Directed, vertexStorageClass, edgeStorageClass, edgeStorageClass);
//            static assert(isGraph!Graph);

//            Graph g;

//            assert(g.vertexCount);
//        }
//    }
//}
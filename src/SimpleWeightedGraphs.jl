module SimpleWeightedGraphs

using Graphs
using LinearAlgebra
using Markdown
using SparseArrays

import Base:
    convert, eltype, show, ==, Pair, Tuple, copy, length, issubset, zero

import Graphs:
    _NI, AbstractGraph, AbstractEdge, AbstractEdgeIter,
    src, dst, edgetype, nv, ne, vertices, edges, is_directed,
    add_vertex!, add_edge!, rem_vertex!, rem_edge!,
    has_vertex, has_edge, inneighbors, outneighbors,
    indegree, outdegree, degree, has_self_loops, num_self_loops,

    add_vertices!, adjacency_matrix, laplacian_matrix, weights,
    connected_components, cartesian_product,

    AbstractGraphFormat, loadgraph, loadgraphs, savegraph,
    pagerank, induced_subgraph

export
    AbstractSimpleWeightedGraph,
    AbstractSimpleWeightedEdge,
    SimpleWeightedEdge,
    SimpleWeightedGraph,
    SimpleWeightedGraphEdge,
    SimpleWeightedDiGraph,
    SimpleWeightedDiGraphEdge,
    weight,
    weighttype,
    get_weight,
    WGraph,
    WDiGraph,
    SWGFormat,
    degree_matrix

include("simpleweightededge.jl")

"""
    AbstractSimpleWeightedGraph

An abstract type representing a simple graph structure.
AbstractSimpleWeightedGraphs must have the following elements:
- weightmx::AbstractSparseMatrix{Real}
"""
abstract type AbstractSimpleWeightedGraph{T<:Integer,U<:Real} <: AbstractGraph{T} end

function show(io::IO, g::AbstractSimpleWeightedGraph{T, U}) where T where U
    dir = is_directed(g) ? "directed" : "undirected"
    print(io, "{$(nv(g)), $(ne(g))} $dir simple $T graph with $U weights")
end

# conversion to SparseMatrixCSC
convert(::Type{SparseMatrixCSC{T, U}}, g::AbstractSimpleWeightedGraph) where T<:Real where U<:Integer = SparseMatrixCSC{T, U}(g.weights)


### INTERFACE

nv(g::AbstractSimpleWeightedGraph{T, U}) where T where U = T(size(weights(g), 1))
vertices(g::AbstractSimpleWeightedGraph{T, U}) where T where U = one(T):nv(g)
eltype(x::AbstractSimpleWeightedGraph{T, U}) where T where U = T
weighttype(x::AbstractSimpleWeightedGraph{T, U}) where T where U = U

# handles single-argument edge constructors such as pairs and tuples
has_edge(g::AbstractSimpleWeightedGraph{T, U}, x) where T where U = has_edge(g, edgetype(g)(x))
add_edge!(g::AbstractSimpleWeightedGraph{T, U}, x) where T where U = add_edge!(g, edgetype(g)(x))

# handles two-argument edge constructors like src,dst
has_edge(g::AbstractSimpleWeightedGraph, x, y) = has_edge(g, edgetype(g)(x, y, 0))
add_edge!(g::AbstractSimpleWeightedGraph, x, y) = add_edge!(g, edgetype(g)(x, y, 1))
add_edge!(g::AbstractSimpleWeightedGraph, x, y, z) = add_edge!(g, edgetype(g)(x, y, z))

function issubset(g::T, h::T) where T<:AbstractSimpleWeightedGraph
    (gmin, gmax) = extrema(vertices(g))
    (hmin, hmax) = extrema(vertices(h))
    return (hmin <= gmin <= gmax <= hmax) && issubset(edges(g), edges(h))
end

has_vertex(g::AbstractSimpleWeightedGraph, v::Integer) = v in vertices(g)

function rem_edge!(g::AbstractSimpleWeightedGraph{T, U}, u::Integer, v::Integer) where {T, U}
    rem_edge!(g, edgetype(g)(T(u), T(v), one(U)))
end

get_weight(g::AbstractSimpleWeightedGraph, u::Integer, v::Integer) = weights(g)[v, u]

zero(g::T) where T<:AbstractSimpleWeightedGraph = T()

# TODO: manipulte SparseMatrixCSC directly
add_vertex!(g::AbstractSimpleWeightedGraph) = add_vertices!(g, 1)

copy(g::T) where T <: AbstractSimpleWeightedGraph =  T(copy(weights(g)))


const SimpleWeightedGraphEdge = SimpleWeightedEdge
const SimpleWeightedDiGraphEdge = SimpleWeightedEdge
include("simpleweighteddigraph.jl")
include("simpleweightedgraph.jl")
include("overrides.jl")
include("persistence.jl")

const WGraph = SimpleWeightedGraph
const WDiGraph = SimpleWeightedDiGraph


# return the index in nzval of mat[i, j]
# we assume bounds are already checked
# see https://github.com/JuliaSparse/SparseArrays.jl/blob/fa547689947fadd6c2f3d09ddfcb5f26536f18c8/src/sparsematrix.jl#L2492 for implementation
@inbounds function _get_nz_index!(mat::SparseMatrixCSC, i::Integer, j::Integer)
    # r1 and r2 are start and end of the column
    r1 = Int(mat.colptr[j])
    r2 = Int(mat.colptr[j+1]-1)
    (r1 > r2) && return 0 # column is empty so we have a non structural zero
    # search if i correspond to a stored value
    indx = searchsortedfirst(mat.rowval, i, r1, r2, Base.Forward)
    ((indx > r2) || (mat.rowval[indx] != i)) && return 0
    return indx
end

SimpleWeightedDiGraph(g::SimpleWeightedGraph) = SimpleWeightedDiGraph(copy(g.weights))
function SimpleWeightedDiGraph{T, U}(g::SimpleWeightedGraph) where {T<:Integer, U<:Real}
    return SimpleWeightedDiGraph(SparseMatrixCSC{U, T}(copy(g.weights)))
end

SimpleWeightedGraph(g::SimpleWeightedDiGraph) = SimpleWeightedGraph(g.weights .+ g.weights')

function SimpleWeightedGraph{T, U}(g::SimpleWeightedDiGraph) where {T<:Integer, U<:Real}
    return SimpleWeightedGraph(SparseMatrixCSC{U, T}(g.weights .+ g.weights'))
end

end # module

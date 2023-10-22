"""
    layerdimensions()

Retrive dimensions of a given fixed-input-size layer.
"""
layerdimensions(l::Flux.Dense) = size(l.weight)
layerdimensions(l::Flux.RNNCell) = (size(l.Wh)[2], size(l.Wi)[2])
layerdimensions(l::Flux.LSTMCell) = (size(l.Wh)[2], size(l.Wi)[2])
layerdimensions(l::Flux.GRUCell) = (size(l.Wh)[2], size(l.Wi)[2])
layerdimensions(r::Flux.Recur) = layerdimensions(r.cell)

"""
    FIXED_INPUT_DIM_LAYERS

List of layers with fixed-size input data
"""
const FIXED_INPUT_DIM_LAYERS = (Flux.Dense, Flux.Recur, Flux.RNNCell, Flux.LSTMCell, Flux.GRUCell)

"""
    get_dimensions(m::Flux.Chain, inp::Union{Nothing, Array, Tuple} = nothing)

Return the dimensions of the input and of the output data of each hidden layer.

If `input_data` is not given, the first layer is required to be a layer
with fixed input dimensions, such as Flux.Dense or Flux.Recur,
otherwise the given data or shape is used to infer the dimensions of each layer.
"""
function get_dimensions(m::Flux.Chain, input_data::Array)

    input_data = fmap(f32, input_data)
    m32 = f32(m)

    chain_dimensions = vcat(size(input_data), [size(m32[1:nl](input_data)) for nl in 1:length(m32.layers)])
    return chain_dimensions
end

function get_dimensions(m::Flux.Chain, ::Nothing=nothing)
    m.layers[1] isa Union{FIXED_INPUT_DIM_LAYERS...} || throw(ArgumentError("An input data or shape is required when the first layer accepts variable-dimension input"))

    input_data = rand(Float32, layerdimensions(m.layers[1])[2])
    return get_dimensions(m, input_data)
end

get_dimensions(m::Flux.Chain, ldim::Tuple) = get_dimensions(m, rand(Float32, ldim))

"""
    UnitVector{T}

Structure for unit vectors in a linear space
    
Used for generating a basis to infer the layer connection
"""
struct UnitVector{T} <: AbstractVector{T}
    idx::Int
    length::Int
end

Base.getindex(x::UnitVector{T}, i) where {T} = x.idx == i ? one(T) : zero(T)
Base.length(x::UnitVector) = x.length
Base.size(x::UnitVector) = (x.length,)

"""
    neuron_indices(ldim:Tuple) -> Vector{NTuple{N, Int}} where N

Return all possible indices for a given Tuple `ldim`.
"""
function neuron_indices(ldim::Tuple)
    return [Tuple(1 + mod(div(i, prod(ldim[1:j-1])), ldim[j]) for j in 1:length(ldim)) for i in 0:prod(ldim)-1]
end

"""
    neuron_connections(m::Flux.Chain, input_data::Union{Nothing,Array,Tuple} = nothing) -> Vector{Dict{Tuple, Vector{Tuple}}}

Return all the connections from every neuron in each layer to the corresponding neurons in the next layer.
"""
function neuron_connections(m::Flux.Chain, input_data::Union{Nothing,Array,Tuple}=nothing)
    chain_dimensions = get_dimensions(m, input_data)
    mn = fneutralize(m)

    connections = Vector{Dict{Tuple,Vector{Tuple}}}()

    for (ln, l) in enumerate(mn)
        ldim = chain_dimensions[ln]
        layer_connections = Dict{Tuple,Vector{Tuple}}()
        basis_element = fill(cold, ldim)
        for idx in neuron_indices(ldim)
            connected = Vector{Tuple}()
            basis_element[idx...] = hot
            union!(connected, Tuple.(findall(x -> x == hot, l(basis_element))))
            push!(layer_connections, idx => connected)
            basis_element[idx...] = cold
        end
        push!(connections, layer_connections)
    end
    return connections
end

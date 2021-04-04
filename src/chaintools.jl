# See Functors.jl https://github.com/FluxML/Functors.jl
# See `show(Chain)T` (not yet implemented): https://github.com/FluxML/Flux.jl/pull/1467
# See https://docs.juliaplots.org/latest/generated/supported/
# See https://fluxml.ai/Flux.jl/stable/models/layers/
# See colors: http://juliagraphics.github.io/Colors.jl/stable/namedcolors/

"""
    layerdimensions()

Retrive dimensions of a given fixed-input-size layer.
"""
layerdimensions(::Any) = (1,1)
layerdimensions(l::Flux.Dense) = size(l.W)
layerdimensions(l::Flux.RNNCell) = (size(l.Wh)[2], size(l.Wi)[2])
layerdimensions(l::Flux.LSTMCell) = (size(l.Wh)[2], size(l.Wi)[2])
layerdimensions(l::Flux.GRUCell) = (size(l.Wh)[2], size(l.Wi)[2])
layerdimensions(r::Flux.Recur) = layerdimensions(r.cell)

"""
    FIXED_INPUT_DIM_LAYERS

List of layers with fixed-sized input data
"""
const FIXED_INPUT_DIM_LAYERS = (Flux.Dense, Flux.Recur, Flux.RNNCell, Flux.LSTMCell, Flux.GRUCell) # list of types of layers with fixed input dimensions

"""
    get_dimensions(m::Flux.Chain, input_data = nothing)

Get the dimensions of the input layer and of the output layer of each hidden layer.

If `input_data` is not given, the first layer is required to be a layer
with fixed input dimensions,  such as Flux.Dense or Flux.Recur,
otherwise the given data is used to infer the dimensions of each layer.
"""
function get_dimensions(m::Flux.Chain, input_data::Union{Nothing,Array} = nothing)

    if m.layers[1] isa Union{FIXED_INPUT_DIM_LAYERS...}
        input_data = rand(Float32, layerdimensions(m.layers[1])[2]) 
    elseif input_data === nothing
        throw(ArgumentError("An `input_data` is required when the first layer accepts variable-dimension input"))
    end

    chain_dimensions = vcat(size(input_data), [size(m[1:nl](input_data)) for nl in 1:length(m.layers)])
    return chain_dimensions
end

"""
    UnitVector{T}

Structure for unit vectors in a linear space
    
Used for generating a basis to infer the layer connection
"""
struct UnitVector{T} <: AbstractVector{T}
    idx::Int
    length::Int
end

Base.getindex(x::UnitVector{T}, i) where T = x.idx==i ? one(T) : zero(T)
Base.length(x::UnitVector) = x.length
Base.size(x::UnitVector) = (x.length,)

"""
    get_cartesians(lsize:Tuple)

Return all possible Cartesian indices for a given `lsize` Tuple.
"""
function get_cartesians(ldim::Tuple)
    cartesians = Array{CartesianIndex,1}()
    foreach(1:prod(ldim)) do idx
        basis_element = reshape(UnitVector{Int}(idx, prod(ldim)),ldim...)
        push!(cartesians, CartesianIndex(findfirst(x->x==1, basis_element)))
    end
    return cartesians
end

"""
    get_connections(m::Flux.Chain)

Get all the connections to the next layer of each neuron in each layer.
"""
function get_connections(m::Flux.Chain, input_data::Union{Nothing,Array} = nothing)
    chain_dimensions = get_dimensions(m, input_data)
    connections = Vector{Dict{CartesianIndex, Vector{CartesianIndex}}}()

    for (ln, l) in enumerate(m)
        ldim = chain_dimensions[ln]
        layer_connections = Dict{CartesianIndex,Array{CartesianIndex,1}}()
        foreach(1:prod(ldim)) do idx
            affected = Array{CartesianIndex,1}()
            basis_element = reshape(UnitVector{Int}(idx, prod(ldim)),ldim...)
            for rv in convert.(Float32, rand(Int16,2))
                union!(affected, CartesianIndex.(findall(x -> abs(x) > eps(), l(rv .* basis_element))))
            end
            push!(layer_connections, CartesianIndex(findfirst(x->x==1, basis_element)) => affected)
        end
        push!(connections, layer_connections)
    end

    return connections
end

"""
    get_max_width(m::Flux.Chain, input_data::Union{Nothing,Array} = nothing)

Get the maximum display width for the chain.
"""
get_max_width(m::Flux.Chain, input_data::Union{Nothing,Array} = nothing) =
    mapreduce(x->x[1], max, get_dimensions(m,input_data))

"""
Return an IO that will always read in the right endianness.
"""
function correct_endianess(io::IO)
    sfnt = Base.peek(io, UInt32)
    if sfnt == 0x00000100
        SwapStream(io)
    else
        io
    end
end

version_16_dot_16(version::UInt32) = VersionNumber(version >> 16 + (version & 0x0000ffff) >> 8)

function word_align(size)
    4 * cld(size, 4)
end

function read_expr(field)
    if isexpr(field, :(::))
        T = field.args[2]
        isexpr(T, :curly) && T.args[1] == :Vector && error("Vectors must have a corresponding length.")
        isexpr(T, :curly) && T.args[1] == :NTuple && return :(Tuple(read(io, $(T.args[2]) for _ in 1:$(T.args[3]))))
        T == :String && error("Strings are not supported yet.")
        return :(read(io, $T))
    elseif isexpr(field, :call) && field.args[1] == :(=>)
        field, length = field.args[2:3]
        if isexpr(field, :(::))
            T = last(field.args)
            isexpr(T, :curly, 2) && T.args[1] == :Vector && return :([read(io, $(T.args[2])) for _ in 1:$length])
        end
    end
    error("Unexpected expression form: $field")
end

"""
Mark a given struct as serializable, automatically implementing `Base.read`.

If some of the structure members are vectors, their length
must be specified using a syntax of the form `params::Vector{UInt32} => param_count`
where `param_count` can be any expression, which may depend on other structure members.
"""
function serializable(ex)
    !isexpr(ex, :struct) && error("Expected a struct definition, got $(repr(ex))")
    typedecl, fields = ex.args[2:3]
    fields = isexpr(fields, :block) ? fields.args : [fields]
    t = typedecl
    isexpr(t, :(<:)) && (t = first(t.args))
    isexpr(t, :curly) && error("Parametric types are not supported.")
    @assert t isa Symbol
    exprs = Expr[]
    lengths = Dict{Symbol,Any}()
    fieldnames = Symbol[]
    fields_nolinenums = filter(!Base.Fix2(isa, LineNumberNode), fields)
    required_fields = Symbol[]
    pruned_fields = Expr[]
    fields_withlength = Symbol[]
    for ex in fields_nolinenums
        if isexpr(ex, :call) && ex.args[1] == :(=>)
            (field, l) = ex.args[2:3]
            push!(pruned_fields, field)
            isexpr(field, :(::)) && (field = first(field.args))
            lengths[field] = l
            push!(fieldnames, field)
            push!(fields_withlength, field)
            isa(l, Symbol) && push!(required_fields, l)
        elseif isexpr(ex, :(::))
            push!(pruned_fields, ex)
            push!(fieldnames, first(ex.args))
        else
            error("Field $(repr(ex)) must be typed.")
        end
    end

    body = Expr(:block)
    for (var, field) in zip(fieldnames, fields_nolinenums)
        push!(body.args, :($var = $(read_expr(field))))
    end
    push!(body.args, :($t($(fieldnames...))))
    read_f = Expr(:function, :(Base.read(io::IO, ::Type{$t})), body)

    fields = map(fields) do ex
        isexpr(ex, :call) && return ex.args[2]
        ex
    end
    struct_def = Expr(:struct, ex.args[1:2]..., Expr(:block, fields...))
    quote
        Core.@__doc__ $struct_def
        $read_f
    end
end

macro serializable(ex)
    esc(serializable(ex))
end

include("parsing/table_records.jl")
include("parsing/font_header.jl")
include("parsing/maximum_profile.jl")
include("parsing/cmap.jl")
include("parsing/metrics.jl")
include("parsing/loca.jl")
include("parsing/variation.jl")

"""
Return an IO that will always read in the right endianness.
"""
function correct_endianess(io::IO)
    SwapStream(peek(io, UInt32) == 0x00000100, io)
end

function word_align(size)
    4 * cld(size, 4)
end

function read_expr(field, linenum::LineNumberNode)
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
    elseif isexpr(field, :call) && field.args[1] == :(<<)
        ex = field.args[3]
        # Add linenum info to comprehensions to make stack traces more readable.
        isexpr(ex, :comprehension) && (ex.args[1].args[1] = Expr(:block, linenum, ex.args[1].args[1]))
        return ex
    end
    error("Unexpected expression form: $field")
end

function serializable(ex, source::LineNumberNode)
    !isexpr(ex, :struct) && error("Expected a struct definition, got $(repr(ex))")
    typedecl, fields = ex.args[2:3]
    fields = isexpr(fields, :block) ? fields.args : [fields]

    argmeta = Expr[]
    filter!(fields) do ex
        if isexpr(ex, :macrocall) && ex.args[1] == Symbol("@arg")
            push!(argmeta, ex)
            false
        else
            true
        end
    end

    t = typedecl
    isexpr(t, :(<:)) && (t = first(t.args))
    isexpr(t, :curly) && error("Parametric types are not supported.")
    @assert t isa Symbol
    exprs = Expr[]
    lengths = Dict{Symbol,Any}()
    fieldnames = Symbol[]
    field_linenums = LineNumberNode[]
    fields_nolinenums = filter(fields) do x
        !isa(x, LineNumberNode) && return true
        push!(field_linenums, x)
        false
    end
    # Ignore linenums for `@arg x` definitions.
    field_linenums = field_linenums[begin + length(argmeta):end]
    required_fields = Symbol[]
    fields_withlength = Symbol[]
    for ex in fields_nolinenums
        if isexpr(ex, :call) && ex.args[1] == :(=>)
            (field, l) = ex.args[2:3]
            isexpr(field, :(::)) && (field = first(field.args))
            lengths[field] = l
            push!(fieldnames, field)
            push!(fields_withlength, field)
            isa(l, Symbol) && push!(required_fields, l)
            continue
        else
            isexpr(ex, :call) && ex.args[1] == :(<<) && (ex = ex.args[2])
            if isexpr(ex, :(::))
                push!(fieldnames, first(ex.args))
                continue
            end
        end
        error("Field $(repr(ex)) must be typed.")
    end

    body = Expr(:block, source, :(__origin__ = position(io)))
    for (linenum, var, field) in zip(field_linenums, fieldnames, fields_nolinenums)
        push!(body.args, linenum, :($var = $(read_expr(field, linenum))))
    end
    push!(body.args, :($t($(fieldnames...))))
    fdecl = :(Base.read(io::IO, ::Type{$t}))
    for ex in argmeta
        if isexpr(ex, :macrocall) && ex.args[1] == Symbol("@arg")
            push!(fdecl.args, last(ex.args))
        end
    end
    read_f = Expr(:function, fdecl, body)

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

"""
Mark a given struct as serializable, automatically implementing `Base.read`.

If some of the structure members are vectors, their length
must be specified using a syntax of the form `params::Vector{UInt32} => param_count`
where `param_count` can be any expression, which may depend on other structure members.

Fields can be read in a custom manner by using a syntax of the form
`params::SomeField << ex` where `ex` can be e.g. `read(io, SomeField, other_field.length)`
where `other_field` can refer to any previous field in the struct. This expression may
refer to a special variable `__origin__`, which is the position of the IO before parsing the struct.y hb

Additional arguments required for `Base.read` can be specified with the syntax `@arg name` at the very start of the structure,
before any actual fields. In this way, the definition for `Base.read` will include these extra arguments. Calling code
will then have to provide these extra arguments.

`LineNumberNode`s will be preserved and inserted wherever necessary to keep stack traces informative.

# Examples

```julia
@serializable struct MarkArrayTable
    mark_count::UInt16
    mark_records::Vector{MarkRecord} => mark_count
end
```

```julia
@serializable struct LigatureAttachTable
    @arg mark_class_count # will need to be provided when `Base.read`ing this type.

    # Length of `component_records`.
    component_count::UInt16

    component_records::Vector{Vector{UInt16}} << [[read(io, UInt16) for _ in 1:mark_class_count] for _ in 1:component_count]
end
```

Here is an advanced example which makes use of all the features:

```julia
@serializable struct LigatureArrayTable
    @arg mark_class_count # will need to be provided when `Base.read`ing this type.

    # Length of `ligature_attach_offsets`.
    ligature_count::UInt16

    # Offsets in bytes from the origin of the structure to data blocks formatted as `LigatureAttachTable`s.
    ligature_attach_offsets::Vector{UInt16} => ligature_count

    ligature_attach_tables::Vector{LigatureAttachTable} << [read_at(io, LigatureAttachTable, offset, mark_class_count; start = __origin__) for offset in ligature_attach_offsets]
end
```
"""
macro serializable(ex)
    try
        ex = serializable(ex, __source__)
    catch
        (; file, line) = __source__
        @error "An error happened while parsing an expression at $file:$line"
        rethrow()
    end

    esc(ex)
end

"""
Read a value of type `T` located at an offset from a given start (defaulting
to the current position), without modifying the stream position.
"""
function read_at(io::IO, @nospecialize(T), offset, args...; start = position(io))
    pos = position(io)
    seek(io, start + offset)
    val = read(io, T, args...)
    seek(io, pos)
    val
end

include("parsing/table_records.jl")
include("parsing/font_header.jl")
include("parsing/maximum_profile.jl")
include("parsing/cmap.jl")
include("parsing/metrics.jl")
include("parsing/loca.jl")
include("parsing/glyf.jl")
include("parsing/coverage.jl")
include("parsing/script.jl")
include("parsing/features.jl")
include("parsing/lookup.jl")
include("parsing/classes.jl")
include("parsing/contextual_tables.jl")
include("parsing/gpos.jl")
include("parsing/gsub.jl")
include("parsing/variation.jl")

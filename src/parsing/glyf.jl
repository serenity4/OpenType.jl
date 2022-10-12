@bitmask SimpleGlyphFlag::UInt8 begin
    ON_CURVE_POINT_BIT =                       0x01
    X_SHORT_VECTOR_BIT =                       0x02
    Y_SHORT_VECTOR_BIT =                       0x04
    REPEAT_FLAG_BIT =                          0x08
    X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT = 0x10
    Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT = 0x20
    OVERLAP_SIMPLE_BIT =                       0x40
    SIMPLE_GLYPH_RESERVED_BIT =                0x80
end

"""
Glyph metadata.

`xmin`, `ymin`, `xmax` and `ymax` describe a bounding box for
these glyphs. The bounding box may or may not be tight.

!!! warning
    In a variable font, the bounding box is only representative of the
    default instance of a glyph. For a non-default instance, the bounding
    box should be recomputed from the points after deltas are applied.
"""
@serializable struct GlyphHeader
    ncontours::Int16
    xmin::Int16
    ymin::Int16
    xmax::Int16
    ymax::Int16
end

"""
Description of a glyph as a series of quadratic bezier patches.

Bezier patches are implicitly defined using a list of glyph points, where two consecutive off-curve points implicitly define an on-curve point halfway.
"""
struct SimpleGlyphTable
    end_pts_of_contours::Vector{UInt16}
    instruction_length::UInt16
    instructions::Vector{UInt8}
    flags::Vector{SimpleGlyphFlag}
    x_coordinates::Vector{Union{UInt8,Int16}}
    y_coordinates::Vector{Union{UInt8,Int16}}
end

function Base.read(io::IO, ::Type{SimpleGlyphTable}, header::GlyphHeader)
    end_pts_of_contours = [read(io, UInt16) for _ in 1:header.ncontours]
    instruction_length = read(io, UInt16)
    instructions = [read(io, UInt8) for _ in 1:instruction_length]
    flags = SimpleGlyphFlag[]
    logical_flags = SimpleGlyphFlag[]
    n = last(end_pts_of_contours) + 1
    while length(logical_flags) < n
        flag = SimpleGlyphFlag(read(io, UInt8))
        push!(flags, flag)
        push!(logical_flags, flag)
        if REPEAT_FLAG_BIT in flag
            repeat_count = read(io, UInt8)
            # Embed the repeat count inside flags to preserve the layout of the data block.
            push!(flags, SimpleGlyphFlag(repeat_count))
            append!(logical_flags, flag for _ in 1:repeat_count)
        end
    end

    length(logical_flags) == n || error("Number of logical flags inconsistent with the number of contour points as specified by the last member of `end_pts_of_contours`: expected $n logical flags, got $(length(logical_flags)).")

    x_coordinates = Union{UInt8,Int16}[]
    sizehint!(x_coordinates, n)
    for flag in logical_flags
        if X_SHORT_VECTOR_BIT in flag
            push!(x_coordinates, read(io, UInt8))
        elseif X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT ∉ flag && X_SHORT_VECTOR_BIT ∉ flag
            push!(x_coordinates, read(io, Int16))
        end
    end

    y_coordinates = Union{UInt8,Int16}[]
    sizehint!(y_coordinates, n)
    for flag in logical_flags
        if Y_SHORT_VECTOR_BIT in flag
            push!(y_coordinates, read(io, UInt8))
        elseif Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT ∉ flag && Y_SHORT_VECTOR_BIT ∉ flag
            push!(y_coordinates, read(io, Int16))
        end
    end

    SimpleGlyphTable(end_pts_of_contours, instruction_length, instructions, flags, x_coordinates, y_coordinates)
end

@bitmask ComponentGlyphFlag::UInt16 begin
    ARG_1_AND_2_ARE_WORDS = 0x0001
    ARGS_ARE_XY_VALUES = 0x0002
    ROUND_XY_TO_GRID = 0x0004
    WE_HAVE_A_SCALE = 0x0008
    MORE_COMPONENTS = 0x0020
    WE_HAVE_AN_X_AND_Y_SCALE = 0x0040
    WE_HAVE_A_TWO_BY_TWO = 0x0080
    WE_HAVE_INSTRUCTIONS = 0x0100
    USE_MY_METRICS = 0x0200
    OVERLAP_COMPOUND = 0x0400
    SCALED_COMPONENT_OFFSET = 0x1000
    RESERVED = 0xe010
end

struct ComponentGlyphTable
    flags::ComponentGlyphFlag
    glyph_index::GlyphID
    argument_1::Union{UInt8,Int8,UInt16,Int16}
    argument_2::Union{UInt8,Int8,UInt16,Int16}
    transform::Optional{Union{F2DOT14,NTuple{2,F2DOT14},NTuple{4,F2DOT14}}}
    num_instr::Optional{UInt16}
    instr::Optional{Vector{UInt8}}
end

function Base.read(io::IO, ::Type{ComponentGlyphTable})
    flags = read(io, ComponentGlyphFlag)
    glyph_index = read(io, UInt16)
    argument_1, argument_2 = if ARG_1_AND_2_ARE_WORDS in flags
        if ARGS_ARE_XY_VALUES in flags
            read(io, Int16), read(io, Int16)
        else
            read(io, UInt16), read(io, UInt16)
        end
    else
        if ARGS_ARE_XY_VALUES in flags
            read(io, Int8), read(io, Int8)
        else
            read(io, UInt8), read(io, UInt8)
        end
    end
    transform = if WE_HAVE_A_SCALE in flags
        read(io, F2DOT14)
    elseif WE_HAVE_AN_X_AND_Y_SCALE in flags
        read(io, F2DOT14), read(io, F2DOT14)
    elseif WE_HAVE_A_TWO_BY_TWO in flags
        read(io, F2DOT14), read(io, F2DOT14), read(io, F2DOT14), read(io, F2DOT14)
    end
    num_instr = instr = nothing
    if WE_HAVE_INSTRUCTIONS in flags
        num_instr = read(io, UInt16)
        instr = [read(io, UInt8) for _ in 1:num_instr]
    end
    ComponentGlyphTable(flags, glyph_index, argument_1, argument_2, transform, num_instr, instr)
end

struct CompositeGlyphTable
    components::Vector{ComponentGlyphTable}
end

function Base.read(io::IO, ::Type{CompositeGlyphTable})
    c = read(io, ComponentGlyphTable)
    components = [c]
    while MORE_COMPONENTS in c.flags
        c = read(io, ComponentGlyphTable)
        push!(components, c)
    end
    CompositeGlyphTable(components)
end

struct Glyph
    header::GlyphHeader
    data::Union{SimpleGlyphTable,CompositeGlyphTable}
end

struct GlyphTable
    glyphs::Vector{Union{Nothing,Glyph}}
end

function Base.read(io::IO, ::Type{GlyphTable}, head::FontHeader, maxp::MaximumProfile, nav::TableNavigationMap, loca::IndexToLocation)
    ranges = glyph_ranges(loca)
    @debug "'loca' data indicates $(length(filter(r -> r.stop ≠ r.start, ranges))) glyph outlines"
    glyphs = map(ranges) do range
        # A glyph for which the range is of zero length has no outline.
        range.stop == range.start && return nothing
        seek(io, nav["glyf"].offset + range.start)
        header = read(io, GlyphHeader)
        data = if header.ncontours == -1
            read(io, CompositeGlyphTable)
        else
            read(io, SimpleGlyphTable, header)
        end
        Glyph(header, data)
    end
    GlyphTable(glyphs)
end

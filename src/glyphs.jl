abstract type GlyphData end

@bitmask_flag SimpleGlyphFlag::UInt8 begin
    ON_CURVE_POINT_BIT =                       0x01
    X_SHORT_VECTOR_BIT =                       0x02
    Y_SHORT_VECTOR_BIT =                       0x04
    REPEAT_FLAG_BIT =                          0x08
    X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT = 0x10
    Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT = 0x20
    OVERLAP_SIMPLE_BIT =                       0x40
    SIMPLE_GLYPH_RESERVED_BIT =                0x80
end

struct GlyphPoint
    coords::Point{2,Int}
    on_curve::Bool
end

"""
Description of a glyph as a series of quadratic bezier patches.

Bezier patches are implicitly defined using a list of `GlyphPoint`s, where two consecutive off-curve points implicitly define an on-curve point halfway.
"""
struct SimpleGlyph <: GlyphData
    end_pts_of_contours::Vector{UInt16}
    instruction_length::UInt16
    instructions::Vector{UInt8}
    flags::Vector{SimpleGlyphFlag}
    x_coordinates::Vector{Union{UInt8,Int16}}
    y_coordinates::Vector{Union{UInt8,Int16}}
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
struct GlyphHeader
    ncontours::Int16
    xmin::Int16
    ymin::Int16
    xmax::Int16
    ymax::Int16
end

Base.read(io::IO, ::Type{GlyphHeader}) = GlyphHeader(read(io, Int16), read(io, Int16), read(io, Int16), read(io, Int16), read(io, Int16))

@bitmask_flag ComponentGlyphFlag::UInt16 begin
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
    glyph_index::UInt16
    argument_1::Union{UInt8,Int8,UInt16,Int16}
    argument_2::Union{UInt8,Int8,UInt16,Int16}
end

struct Glyph
    header::GlyphHeader
    data::Union{SimpleGlyph,ComponentGlyphTable}
end

"""
Extract all quadratic bezier control points explicitly from a glyph.

In OpenType, control points may be stored using an implicit format, where two consecutive points may be marked as off-curve although the curve is quadratic: in this case, it means that there is an implicit control point halfway.
"""
function uncompress(glyph::Glyph)
    data = glyph.data

    contour_indices = [0; data.contour_indices]
    ranges = map(zip(contour_indices[begin:end-1], contour_indices[begin+1:end])) do (i, j)
        (i+1):j
    end

    curves = Vector{Point{2,Float64}}[]
    for data_points in map(Base.Fix1(getindex, data.points), ranges)
        points = Point{2,Float64}[]

        # make sure data points define a closed contour
        while !(first(data_points).on_curve)
            push!(data_points, popfirst!(data_points))
        end
        if last(data_points) ≠ first(data_points)
            # terminate with a linear segment
            push!(data_points, first(data_points))
        end

        # gather contour points including implicit ones
        on_curve = false
        for point in data_points
            coords = point.coords
            if !on_curve && !point.on_curve || on_curve && point.on_curve
                # there is an implicit on-curve point halfway
                push!(points, (coords + points[end]) / 2)
            end
            push!(points, coords)
            on_curve = point.on_curve
        end

        @assert isodd(length(points)) "Expected an odd number of curve points."
        @assert first(points) == last(points) "Contour is not closed."
        push!(curves, points)
        on_curve = true
    end

    curves
end

function normalize(curves, glyph::Glyph)
    min = Point(glyph.header.xmin, glyph.header.ymin)
    max = Point(glyph.header.xmax, glyph.header.ymax)
    from = box(min, max)
    to = box(Point{2,Int16}(0, 0), Point{2,Int16}(1, 1))
    transf = BoxTransform(from, to)
    map(curves) do points
        @assert all(min[1] ≤ minimum(getindex.(points, 1)))
        @assert all(min[2] ≤ minimum(getindex.(points, 2)))
        @assert all(max[1] ≥ maximum(getindex.(points, 1)))
        @assert all(max[2] ≥ maximum(getindex.(points, 2)))
        res = transf.(points)
        @assert all(p -> all(0 .≤ p .≤ 1), res)
        res
    end
end

function curves(glyph::Glyph)
    patch = Patch(BezierCurve(), 3)
    curves = normalize(uncompress(glyph), glyph)
    [map(Base.Fix2(split, patch), curves)...;]
end

function Base.read(io::IO, ::Type{ComponentGlyphTable}, header::GlyphHeader)
    error("Not implemented.")
end

function Base.read(io::IO, ::Type{SimpleGlyph}, header::GlyphHeader)
    end_pts_of_contours = [read(io, UInt16) for _ in 1:header.ncontours]
    instruction_length = read(io, UInt16)
    instructions = [read(io, UInt8) for _ in 1:instruction_length]
    flags = SimpleGlyphFlag[]
    logical_flags = SimpleGlyphFlag[]
    while length(logical_flags) < last(end_pts_of_contours) + 1
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

    length(logical_flags) == last(end_pts_of_contours) + 1 || error("Number of logical flags inconsistent with the number of contour points as specified by the last member of `end_pts_of_contours`: expected $(last(end_pts_of_contours) + 1) logical flags, got $(length(logical_flags)).")

    x_coordinates = Union{UInt8,Int16}[]
    for flag in logical_flags
        if X_SHORT_VECTOR_BIT in flag
            push!(x_coordinates, read(io, UInt8))
        elseif X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT ∉ flag && X_SHORT_VECTOR_BIT ∉ flag
            push!(x_coordinates, read(io, Int16))
        end
    end

    y_coordinates = Union{UInt8,Int16}[]
    for flag in logical_flags
        if Y_SHORT_VECTOR_BIT in flag
            push!(y_coordinates, read(io, UInt8))
        elseif Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT ∉ flag && Y_SHORT_VECTOR_BIT ∉ flag
            push!(y_coordinates, read(io, Int16))
        end
    end

    SimpleGlyph(end_pts_of_contours, instruction_length, instructions, flags, x_coordinates, y_coordinates)
end

function read_glyphs(io::IO, head::FontHeader, maxp::MaximumProfile, nav::TableNavigationMap, loca::IndexToLocation)
    glyphs = map(glyph_ranges(loca)) do range
        range.stop == range.start && return nothing
        seek(io, nav["glyf"].offset + range.start)
        header = read(io, GlyphHeader)
        data = if header.ncontours == -1
            read(io, ComponentGlyphTable, header)
        else
            read(io, SimpleGlyph, header)
        end
        Glyph(header, data)
    end
end

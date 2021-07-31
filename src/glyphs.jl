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
struct GlyphSimple <: GlyphData
    contour_indices::Vector{Int}
    points::Vector{GlyphPoint}
end

Base.show(io::IO, gdata::GlyphSimple) = print(io, "GlyphSimple(", length(gdata.points), " points, ", length(gdata.contour_indices), " indices)")

struct GlyphHeader
    ncontours::Int16
    xmin::Int16
    ymin::Int16
    xmax::Int16
    ymax::Int16
end

struct Glyph{D<:GlyphData}
    header::GlyphHeader
    data::D
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
    sc = inv(Scaling(max - min))
    transf = sc ∘ Translation(-min)
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

function read_glyphs(io::IO, head::FontHeader, maxp::MaximumProfile, nav::TableNavigationMap, loca::IndexToLocation)
    glyphs = map(glyph_ranges(loca)) do range
        range.stop == range.start && return nothing
        read_table(io, nav["glyf"]; offset = range.start, length = range.stop - range.start) do io
            header = GlyphHeader(
                (read(io, T) for T in fieldtypes(GlyphHeader))...
            )
            data = if header.ncontours ≠ -1
                end_contour_points = [read(io, UInt16) for _ in 1:header.ncontours]

                # convert to 1-based indexing
                end_contour_points .+= 1

                instlength = read(io, UInt16)
                insts = [read(io, UInt8) for _ in 1:instlength]
                end_idx = end_contour_points[end]
                flags = SimpleGlyphFlag[]
                while length(flags) < end_idx
                    flag = SimpleGlyphFlag(read(io, UInt8))
                    push!(flags, flag)
                    if REPEAT_FLAG_BIT in flag
                        repeat_count = read(io, UInt8)
                        append!(flags, (flag for _ in 1:repeat_count))
                    end
                end

                xs = Int[]
                foreach(flags) do flag
                    x = if X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT in flag && X_SHORT_VECTOR_BIT ∉ flag
                        val = isempty(xs) ? 0 : last(xs)
                        push!(xs, val)
                        return
                    elseif X_SHORT_VECTOR_BIT in flag
                        val = Int(read(io, UInt8))
                        X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT in flag ? val : -val
                    elseif X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT ∉ flag && X_SHORT_VECTOR_BIT ∉ flag
                        read(io, Int16)
                    end
                    push!(xs, x + (isempty(xs) ? 0 : last(xs)))
                end

                ys = Int[]
                foreach(flags) do flag
                    y = if Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT in flag && Y_SHORT_VECTOR_BIT ∉ flag
                        val = isempty(ys) ? 0 : last(ys)
                        push!(ys, val)
                        return
                    elseif Y_SHORT_VECTOR_BIT in flag
                        val = Int(read(io, UInt8))
                        Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT in flag ? val : -val
                    elseif Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT ∉ flag && Y_SHORT_VECTOR_BIT ∉ flag
                        read(io, Int16)
                    end
                    push!(ys, y + (isempty(ys) ? 0 : last(ys)))
                end
                GlyphSimple(
                    end_contour_points,
                    GlyphPoint.(collect(zip(xs, ys)), map(Base.Fix1(in, ON_CURVE_POINT_BIT), flags)),
                )
            end
            if position(io) % 4 ≠ 0
                # rest should just be padding zeros
                @assert all(iszero, read(io, UInt8) for _ in 1:4 - position(io) % 4)
            end
            Glyph(header, data)
        end
    end
end

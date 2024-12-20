const GlyphOutline = Vector{Vec2}

struct SimpleGlyph
    id::GlyphID
    outlines::Vector{GlyphOutline}
    # Keep the header around for normalization.
    header::GlyphHeader
end

boundingelement(outlines::AbstractVector{GlyphOutline}) = boundingelement(PointSet(outline) for outline in outlines)
boundingelement(glyph::SimpleGlyph) = boundingelement(glyph.outlines)

Base.show(io::IO, glyph::SimpleGlyph) = print(io, SimpleGlyph, "(", glyph.id, ", ", length(glyph.outlines), " outlines)")

struct CompositeGlyphComponent
    flags::ComponentGlyphFlag
    glyph_index::GlyphID
    offset::NTuple{2,Int16}
    transform::Optional{Union{F2DOT14, NTuple{2,F2DOT14}, NTuple{4,F2DOT14}}}
end

struct CompositeGlyph
    id::GlyphID
    components::Vector{CompositeGlyphComponent}
end

function logical_flags(glyph::SimpleGlyphTable)
    n = last(glyph.end_pts_of_contours) + 1
    i = 1
    flags = SimpleGlyphFlag[]
    while length(flags) < n
        flag = glyph.flags[i]
        i += 1
        push!(flags, flag)
        if REPEAT_FLAG_BIT in flag
            repeat_count = UInt16(glyph.flags[i])
            i += 1
            append!(flags, flag for _ in 1:repeat_count)
        end
    end
    flags
end

struct GlyphPointInfo
    coords::Vec{2,Int16}
    on_curve::Bool
end

function extract_points(glyph::SimpleGlyphTable)
    flags = logical_flags(glyph)
    points = Vector{GlyphPointInfo}(undef, last(glyph.end_pts_of_contours) + 1)

    ix = 1
    iy = 1
    for (i, flag) in enumerate(flags)
        x = if X_SHORT_VECTOR_BIT ∉ flag && X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT in flag
            i == 1 ? zero(Int16) : points[i-1].coords[1]
        else
            offset = Int16(glyph.x_coordinates[ix])
            ix += 1
            X_SHORT_VECTOR_BIT in flag && X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT ∉ flag && (offset = -offset)
            i == 1 ? offset : points[i-1].coords[1] + offset
        end
        y = if Y_SHORT_VECTOR_BIT ∉ flag && Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT in flag
            i == 1 ? zero(Int16) : points[i-1].coords[2]
        else
            offset = Int16(glyph.y_coordinates[iy])
            iy += 1
            Y_SHORT_VECTOR_BIT in flag && Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT ∉ flag && (offset = -offset)
            i == 1 ? offset : points[i-1].coords[2] + offset
        end
        points[i] = GlyphPointInfo(Vec(x, y), ON_CURVE_POINT_BIT in flag)
    end
    points
end

"""
Extract absolute points from a `SimpleGlyphTable`, applying offsets and materializing implicit points.
"""
function SimpleGlyph(id::GlyphID, glyph::SimpleGlyphTable, header::GlyphHeader)
    contour_indices = [0; glyph.end_pts_of_contours .+ 1]
    ranges = map(zip(contour_indices[begin:end-1], contour_indices[begin+1:end])) do (i, j)
        (i+1):j
    end
    outlines = GlyphOutline[]
    for data_points in map(Base.Fix1(getindex, extract_points(glyph)), ranges)
        points = GlyphOutline()
        sizehint!(points, length(data_points))

        # Make sure data points define a closed contour.
        if !data_points[1].on_curve
            if data_points[2].on_curve
                push!(data_points, popfirst!(data_points))
            elseif data_points[end].on_curve
                pushfirst!(data_points, pop!(data_points))
            else
                push!(data_points, popfirst!(data_points))
                pushfirst!(data_points, GlyphPointInfo((data_points[1].coords + data_points[end].coords) .÷ 2, true))
            end
        end
        if last(data_points) ≠ first(data_points)
            # terminate with a linear segment
            push!(data_points, first(data_points))
        end

        # Gather contour points including implicit ones.
        on_curve = false
        for point in data_points
            coords = point.coords
            if !on_curve && !point.on_curve || on_curve && point.on_curve
                # There is an implicit on-curve point halfway.
                push!(points, (coords + points[end]) .÷ 2)
            end
            push!(points, coords)
            on_curve = point.on_curve
        end

        @assert isodd(length(points)) "Expected an odd number of curve points."
        @assert first(points) == last(points) "Contour is not closed."
        push!(outlines, points)
        on_curve = true
    end
    SimpleGlyph(id, outlines, header)
end

CompositeGlyphComponent(data::ComponentGlyphTable) = CompositeGlyphComponent(data.flags, data.glyph_index, (data.argument_1, data.argument_2), data.transform)

function read_glyphs(data::OpenTypeData)
    (; glyf) = data
    glyphs = Union{Nothing, SimpleGlyph, CompositeGlyph}[]
    for (i, glyph) in enumerate(glyf.glyphs)
        if isnothing(glyph)
            push!(glyphs, glyph)
            continue
        end
        glyph_id = GlyphID(i - 1)
        (; data, header) = glyph
        push!(glyphs, isa(data, SimpleGlyphTable) ? SimpleGlyph(glyph_id, data, header) : CompositeGlyph(glyph_id, CompositeGlyphComponent.(data.components)))
    end
    glyphs
end

"""
Return a list of quadratic Bézier curves corresponding to the glyph's outlines.
"""
function curves(outlines)
    curves = Vec{3,Vec2}[]
    for outline in outlines
        patch = Patch{BezierCurve,3}(outline)
        patch = decompactify(patch)
        for curve in patch
            push!(curves, curve.points)
        end
    end
    curves
end

curves(glyph::SimpleGlyph) = curves(glyph.outlines)
curves(glyph::CompositeGlyph) = error("Composite glyphs are not supported yet.")

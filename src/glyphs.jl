const GlyphOutline = Vector{Point{2,Float64}}

struct SimpleGlyph
    outlines::Vector{GlyphOutline}
end

struct CompositeGlyphComponent
    glyph_index::UInt16
    offset::Translation{2,Int16}
    scale::Scaling{2,Float64}
end

struct CompositeGlyph
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
    coords::Point{2,Int16}
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
        points[i] = GlyphPointInfo(Point(x, y), ON_CURVE_POINT_BIT in flag)
    end
    points
end

"""
Extract absolute points from a `SimpleGlyphTable`, applying offsets and materializing implicit points.
"""
function SimpleGlyph(glyph::SimpleGlyphTable)
    contour_indices = [0; glyph.end_pts_of_contours .+ 1]
    ranges = map(zip(contour_indices[begin:end-1], contour_indices[begin+1:end])) do (i, j)
        (i+1):j
    end
    outlines = GlyphOutline[]
    for data_points in map(Base.Fix1(getindex, extract_points(glyph)), ranges)
        points = GlyphOutline()
        sizehint!(points, length(data_points))

        # Make sure data points define a closed contour.
        while !(first(data_points).on_curve)
            push!(data_points, popfirst!(data_points))
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
                push!(points, (coords + points[end]) / 2)
            end
            push!(points, coords)
            on_curve = point.on_curve
        end

        @assert isodd(length(points)) "Expected an odd number of curve points."
        @assert first(points) == last(points) "Contour is not closed."
        push!(outlines, points)
        on_curve = true
    end
    SimpleGlyph(outlines)
end

function read_glyphs(data::OpenTypeData)
    (; glyf) = data
    glyphs = Union{SimpleGlyph, CompositeGlyph}[]
    for glyph in glyf.glyphs
        isnothing(glyph) && continue
        data = glyph.data
        if data isa SimpleGlyphTable
            push!(glyphs, SimpleGlyph(data))
        else
            error("Composite glyphs not supported yet.")
        end
    end
    glyphs
end

function normalize(outlines, header::GlyphHeader)
    min = Point(header.xmin, header.ymin)
    max = Point(header.xmax, header.ymax)
    from = box(min, max)
    to = box(Point{2,Int16}(0, 0), Point{2,Int16}(1, 1))
    transf = BoxTransform(from, to)
    map(points -> transf.(points), outlines)
end

function curves(glyph::SimpleGlyph)
    patch = Patch(BezierCurve(), 3)
    [[split(outline, patch) for outline in glyph.outlines]...;]
end

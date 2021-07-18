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
            coords = Point(point.coords)
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

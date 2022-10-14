using OpenType
using OpenType: curves, curves_normalized
using GeometryExperiments
using GeometryExperiments: BezierCurve

function intensity(curve_points, pixel_per_em)
    @assert length(curve_points) == 3
    res = 0.
    for coord in 1:2
        (x̄₁, x̄₂, x̄₃) = getindex.(curve_points, 3 - coord)
        if maximum(getindex.(curve_points, coord)) * pixel_per_em ≤ -0.5
            continue
        end
        rshift = sum(((i, x̄),) -> x̄ > 0 ? (1 << i) : 0, enumerate((x̄₁, x̄₂, x̄₃)))
        code = (0x2e74 >> rshift) & 0x0003
        if code ≠ 0
            a = x̄₁ - 2x̄₂ + x̄₃
            b = x̄₁ - x̄₂
            c = x̄₁
            if isapprox(a, 0, atol=1e-7)
                t₁ = t₂ = c / 2b
            else
                Δ = b ^ 2 - a * c
                if Δ < 0
                    # in classes C and F, only x̄₂ is of the opposite sign
                    # and there may be no real roots.
                    continue
                end
                δ = sqrt(Δ)
                t₁ = (b - δ) / a
                t₂ = (b + δ) / a
            end
            bezier = BezierCurve()
            if code & 0x0001 == 0x0001
                val = clamp(pixel_per_em * bezier(t₁, curve_points)[coord] + 0.5, 0, 1)
            end
            if code > 0x0001
                val = -clamp(pixel_per_em * bezier(t₂, curve_points)[coord] + 0.5, 0, 1)
            end
            res += val * (coord == 1 ? 1 : -1)
        end
    end
    res
end

function intensity(point, glyph::OpenType.SimpleGlyph, units_per_em; font_size=12)
    res = sum(curves_normalized(glyph)) do p
        poffset = map(Translation(-point), p)
        intensity(poffset, font_size)
    end
    sqrt(abs(res))
end


function plot_outline(glyph)
    cs = curves(glyph)
    p = plot()
    for (i, curve) in enumerate(cs)
        for (i, point) in enumerate(curve)
            color = i == 1 ? :blue : i == 2 ? :cyan : :green
            scatter!(p, [point[1]], [point[2]], legend=false, color=color)
        end
        points = BezierCurve().(0:0.1:1, Ref(curve))
        curve_color = UInt8[255 - Int(floor(i / length(cs) * 255)), 40, 40]
        plot!(p, first.(points), last.(points), color=string('#', bytes2hex(curve_color)))
    end
    p
end

function render_glyph(font, glyph, font_size)
    step = 0.01
    n = Int(inv(step))
    xs = 0:step:1
    ys = 0:step:1

    grid = map(xs) do x
        map(ys) do y
            Point(x, y)
        end
    end

    grid = hcat(grid...)

    is = map(grid) do p
        try
            intensity(p, glyph, font.units_per_em; font_size)
        catch e
            if e isa DomainError
                NaN
            else
                rethrow(e)
            end
        end
    end
    @assert !all(iszero, is)

    p = heatmap(is)
    xticks!(p, 1:n ÷ 10:n, string.(xs[1:n ÷ 10:n]))
    yticks!(p, 1:n ÷ 10:n, string.(ys[1:n ÷ 10:n]))
end

render_glyph(font, char::Char, font_size) = render_glyph(font, font[char], font_size)

using Plots

font = OpenTypeFont(joinpath(dirname(@__DIR__), "assets", "fonts", "juliamono-regular.ttf"));

glyph = font.glyphs[563]

glyph = font.glyphs[64]
plot_outline(glyph)
render_glyph(font, glyph, 12)

glyph = font.glyphs[75]
plot_outline(glyph)
render_glyph(font, glyph, 12)

glyph = font.glyphs[13]
plot_outline(glyph)
render_glyph(font, glyph, 12)

render_glyph(font, '€', 12)

render_glyph(font, 'A', 12)

using OpenType
using OpenType: curves, curves_normalized
using GeometryExperiments
using GeometryExperiments: BezierCurve
using Plots: plot, plot!, scatter!

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

# `font_file` defined in `test/utils.jl`.
# You can use your own font and skip reassigning the variable.
font = OpenTypeFont(font_file("juliamono"));

# Note that indices to `font.glyphs` correspond to `glyph_id + 1`.
# You can use `font[GlyphID(id)]` to directly access a glyph by its ID.

plot_outline(font[0x003c])
plot_outline(font[0x0054])

glyph = font.glyphs[64]
plot_outline(glyph)

glyph = font.glyphs[75]
plot_outline(glyph)

glyph = font.glyphs[13]
plot_outline(glyph)

# Lao characters.
plot_outline(font['\ue99'])
plot_outline(font['\ueb5'])
plot_outline(font['\uec9'])

using OpenType
using OpenType: curves, curves_normalized
using GeometryExperiments
using GeometryExperiments: BezierCurve
using Plots: plot, plot!, scatter!

function plot_outline!(plot, curves, offset = 0)
  for (i, curve) in enumerate(curves)
    # Scatter control points.
    for (i, point) in enumerate(curve)
      point = point .+ offset
      color = i == 1 ? :blue : i == 2 ? :cyan : :green
      scatter!(plot, [point[1]], [point[2]], legend=false, color=color)
    end

    # Add curve outlines.
    points = BezierCurve().(0:0.1:1, Ref(curve)) .+ Ref(offset)
    curve_color = UInt8[255-Int(floor(i / length(curves) * 255)), 40, 40]
    plot!(plot, first.(points), last.(points), color=string('#', bytes2hex(curve_color)))
  end
  plot
end

plot_outline(glyph) = plot_outline!(plot(), curves(glyph))

function plot_outline(font, glyphs, positions)
  p = plot()
  pen = (0, 0)
  for (glyph, position) in zip(glyphs, positions)
    plot_outline!(p, curves(font[glyph]), pen .+ position.origin)
    pen = pen .+ position.advance
  end
  p
end

# `font_file` defined in `test/utils.jl`.
# You can use your own font and skip reassigning the variable.
font = OpenTypeFont(font_file("juliamono"));

plot_outline(font, glyphs, positions)
plot_outline(font, hb_glyphs, hb_positions)

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

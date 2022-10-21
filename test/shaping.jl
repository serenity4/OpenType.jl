using OpenType: glyph_index, HorizontalMetric
using JSON3
using GeometryExperiments

function horizontal_metric(data::OpenTypeData, glyph::GlyphID)
  (; metrics, left_side_bearings) = data.hmtx
  idx = glyph + 1
  idx > length(metrics) && return HorizontalMetric(last(metrics).advance_width, left_side_bearings[idx - length(metrics)])
  metrics[idx]
end

function computed_offsets(data::OpenTypeData, font::OpenTypeFont, text::AbstractString; apply_positioning = true)
  glyph_ids = glyph_index.(font, collect(text))
  glyphs = getindex.(Ref(font.glyphs), glyph_ids .+ 1)
  offsets = [GlyphOffset(Point(0, 0), Point(metric.advance_width, 0)) for metric in [horizontal_metric(data, id) for id in glyph_ids]]
  !apply_positioning && return offsets
  offsets .+ glyph_offsets(font.gpos, glyphs, "latn", "AZE ", Set{String}())
end

@testset "Shaping" begin
  # A font with ligatures and kerning.
  file = first(google_font_files["notoserifgujarati"])
  data = OpenTypeData(file);
  font = OpenTypeFont(data);

  text = "AV"
  @test computed_offsets(data, font, text; apply_positioning = false) == [GlyphOffset(Point(0, 0), Point(705, 0)), GlyphOffset(Point(0, 0), Point(675, 0))]
  @test computed_offsets(data, font, text) == [GlyphOffset(Point(0, 0), Point(665, 0)), GlyphOffset(Point(0, 0), Point(675, 0))]
end

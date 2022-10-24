using OpenType: glyph_index, horizontal_metric, Tag
using GeometryExperiments

function computed_offsets(font::OpenTypeFont, text::AbstractString; apply_positioning = true, script = tag"latn", lang = tag"AZE ")
  glyph_ids = glyph_index.(font, collect(text))
  glyphs = getindex.(Ref(font.glyphs), glyph_ids .+ 1)
  offsets = [GlyphOffset(Point(0, 0), Point(metric.advance_width, 0)) for metric in [horizontal_metric(font.hmtx, id) for id in glyph_ids]]
  !apply_positioning && return offsets
  offsets .+ glyph_offsets(font.gpos, glyphs, script, lang, Set{Tag{4}}())
end

get_offsets(font::OpenTypeFont, text::AbstractString, script = tag"DFLT", lang = tag"dflt") = glyph_offsets(font.gpos, getindex.(font, collect(text)), script, lang, Set{Tag{4}}())
offsets_devanagari(font, text) = get_offsets(font, text, "deva", tag"HIN ")

@testset "Shaping" begin
  # A font with kerning.
  font = OpenTypeFont(first(google_font_files["notoserifgujarati"]));
  @test computed_offsets(font, "AV"; apply_positioning = false) == [GlyphOffset(Point(0, 0), Point(705, 0)), GlyphOffset(Point(0, 0), Point(675, 0))]
  @test computed_offsets(font, "AV") == [GlyphOffset(Point(0, 0), Point(665, 0)), GlyphOffset(Point(0, 0), Point(675, 0))]

  # Lao script & language. Has lots of diacritic marks for use with mark-to-base and mark-to-mark positioning tests.
  font = OpenTypeFont(first(google_font_files["notoseriflao"]));

  # Simple mark-to-base positioning.
  @test get_offsets(font, "ສົ", tag"lao ") == [zero(GlyphOffset), GlyphOffset(Point(-597, 0), Point(0, 0))]
  @test get_offsets(font, "ກີບ", tag"lao ") == [zero(GlyphOffset), GlyphOffset(Point(-629, 0), Point(0, 0)), zero(GlyphOffset)]

  # Mark-to-base and mark-to-mark positioning. The text may not be rendered correctly on an editor, but marks should neatly stack on top of each other so that we have three distinct graphemes: the base, first mark above the base, and second mark above the mark.
  # TODO: Finalize test once advances are also computed so that we can check the result.
  # @test get_offsets(font, "ນີ້", "lao ") == [zero(GlyphOffset), GlyphOffset(Point(-629, 0), Point(0, 0)), zero(GlyphOffset)]

  # Hindi language, based on the Devanagari script. Seems to have lots of substitutions including contextual substitutions.
  font = OpenTypeFont(first(google_font_files["notoserifdevanagari"]));
  # TODO
end

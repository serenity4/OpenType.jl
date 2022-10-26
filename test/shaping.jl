using OpenType: glyph_index, horizontal_metric, Tag
using GeometryExperiments

@testset "Shaping" begin
  # A font with kerning.
  font = OpenTypeFont(first(google_font_files["notoserifgujarati"]));
  options = ShapingOptions(tag"latn", tag"fra ")
  @test last(shape(font, "AV", options)) == [GlyphOffset(Point(0, 0), Point(665, 0)), GlyphOffset(Point(0, 0), Point(675, 0))]

  # Lao script & language. Has lots of diacritic marks for use with mark-to-base and mark-to-mark positioning tests.
  font = OpenTypeFont(first(google_font_files["notoseriflao"]));
  options = ShapingOptions(tag"lao ", tag"dflt")

  # Simple mark-to-base positioning.
  @test last(shape(font, "ສົ", options)) == [GlyphOffset(Point(0, 0), Point(603, 0)), GlyphOffset(Point(-6, 0), Point(0, 0))]
  @test last(shape(font, "ກີບ", options)) == [GlyphOffset(Point(0, 0), Point(633, 0)), GlyphOffset(Point(-4, 0), Point(0, 0)), GlyphOffset(Point(0, 0), Point(635, 0))]

  # Mark-to-base and mark-to-mark positioning. The text may not be rendered correctly on an editor, but marks should neatly stack on top of each other so that we have three distinct graphemes: the base, first mark above the base, and second mark above the mark.
  @test last(shape(font, "\ue99\ueb5\uec9", options)) == [GlyphOffset(Point(0, 0), Point(606, 0)), GlyphOffset(Point(24, 0), Point(0, 0)), GlyphOffset(Point(24, 339), Point(0, 0))]

  # Hindi language, based on the Devanagari script. Seems to have lots of substitutions including contextual substitutions.
  font = OpenTypeFont(first(google_font_files["notoserifdevanagari"]));
  options = ShapingOptions(tag"deva", tag"HIN ")
  # TODO
end

@testset "Shaping" begin
  file = google_font_files["inter"][1]
  font = OpenTypeFont(file);
  text = "=>"
  # A (likely) non-existing script should provide no features, but never error.
  options = ShapingOptions(tag"blop", tag"blip")
  glyphs, positions = shape(font, text, options)
  @test isa(glyphs, Vector{GlyphID}) && isa(positions, Vector{GlyphOffset})
  options = ShapingOptions(tag"latn", tag"fra ")
  glyphs, positions = shape(font, text, options)
  @test glyphs == [0x06b1]
  @test positions == [GlyphOffset(0, 0, 2688, 0)]
  hb_glyphs, hb_positions = hb_shape(file, text, options)
  @test (glyphs, positions) == (hb_glyphs, hb_positions)

  # A font with kerning.
  file = google_font_files["notoserifgujarati"][1]
  font = OpenTypeFont(file);
  options = ShapingOptions(tag"latn", tag"fra ")
  text = "AV"
  glyphs, positions = shape(font, text, options)
  @test glyphs == [0x01d1, 0x0232]
  @test positions == [GlyphOffset(0, 0, 625, 0), GlyphOffset(0, 0, 675, 0)]

  # Cursive positioning rules.
  # TODO

  # Lao script & language. Has lots of diacritic marks for use with mark-to-base and mark-to-mark positioning tests.
  file = google_font_files["notoseriflao"][1]
  font = OpenTypeFont(file);
  options = ShapingOptions(tag"lao ", tag"dflt")

  # Simple mark-to-base positioning.

  text = "ສົ"

  glyphs, positions = shape(font, text, options)
  @test glyphs == [0x001b, 0x003f]
  @test positions == [GlyphOffset(0, 0, 603, 0), GlyphOffset(-6, 0, 0, 0)]

  text = "ກີບ"
  glyphs, positions = shape(font, text, options)
  @test positions == [GlyphOffset(0, 0, 633, 0), GlyphOffset(-4, 0, 0, 0), GlyphOffset(0, 0, 635, 0)]
  @test glyphs == [0x0004, 0x003c, 0x0010]

  # Mark-to-base and mark-to-mark positioning. The text may not be rendered correctly on an editor, but marks should neatly stack on top of each other so that we have three distinct graphemes: the base, first mark above the base, and second mark above the mark.
  text = "\ue99\ueb5\uec9"
  glyphs, positions = shape(font, text, options)
  @test glyphs == [0x000f, 0x003c, 0x0044]
  @test positions == [GlyphOffset(0, 0, 606, 0), GlyphOffset(24, 0, 0, 0), GlyphOffset(24, 285, 0, 0)]

  # Hindi language, based on the Devanagari script. Seems to have lots of substitutions including contextual substitutions.
  file = google_font_files["notoserifdevanagari"][1]
  font = OpenTypeFont(file);
  options = ShapingOptions(tag"deva", tag"HIN ")
  text = "ल\u094dल"
  glyphs, positions = shape(font, text, options)
  @test glyphs == [0x0116, 0x0053]
  @test positions == [GlyphOffset(0, 0, 449, 0), GlyphOffset(0, 0, 655, 0)]

  # Font without GPOS nor GSUB table.
  file = google_font_files["jejumyeongjo"][1]
  font = OpenTypeFont(file);
  options = ShapingOptions(tag"latn", tag"fra ")
  glyphs, positions = shape(font, "Hello world", options)
  @test !isempty(glyphs) && !isempty(positions)
end;

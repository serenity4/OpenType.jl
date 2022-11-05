using GeometryExperiments

@testset "Shaping" begin
  # A font with kerning.
  font = OpenTypeFont(first(google_font_files["notoserifgujarati"]));
  options = ShapingOptions(tag"latn", tag"fra ")
  glyphs, pos = shape(font, "AV", options; info = (info = ShapingInfo()))
  @test glyphs == [0x01d0, 0x0232]
  @test pos == [GlyphOffset(0, 0, 665, 0), GlyphOffset(0, 0, 675, 0)]
  @test length(info.substitutions) == 0
  @test length(info.positionings) == 1
  @test info.positionings[1].type == POSITIONING_RULE_PAIR_ADJUSTMENT
  @test info.positionings[1].offsets == (glyphs => [GlyphOffset(0, 0, -40, 0), GlyphOffset(0, 0, 0, 0)])

  # Cursive positioning rules.
  # TODO

  # Lao script & language. Has lots of diacritic marks for use with mark-to-base and mark-to-mark positioning tests.
  file = first(google_font_files["notoseriflao"])
  font = OpenTypeFont(file);
  options = ShapingOptions(tag"lao ", tag"dflt")

  # Simple mark-to-base positioning.
  glyphs, pos = shape(font, "ສົ", options; info = (info = ShapingInfo()))
  @test glyphs == [0x001b, 0x003f]
  @test pos == [GlyphOffset(0, 0, 603, 0), GlyphOffset(-6, 0, 0, 0)]
  @test length(info.substitutions) == 0
  @test length(info.positionings) == 1
  @test info.positionings[1].type == POSITIONING_RULE_MARK_TO_BASE
  @test info.positionings[1].offsets == (glyphs[2] => GlyphOffset(-6, 0, 0, 0))
  glyphs, pos = shape(font, "ກີບ", options; info = (info = ShapingInfo()))
  @test pos == [GlyphOffset(0, 0, 633, 0), GlyphOffset(-4, 0, 0, 0), GlyphOffset(0, 0, 635, 0)]
  @test glyphs == [0x0004, 0x003c, 0x0010]
  @test length(info.substitutions) == 0
  @test length(info.positionings) == 1
  @test info.positionings[1].type == POSITIONING_RULE_MARK_TO_BASE
  @test info.positionings[1].offsets == (glyphs[2] => GlyphOffset(-4, 0, 0, 0))

  # Mark-to-base and mark-to-mark positioning. The text may not be rendered correctly on an editor, but marks should neatly stack on top of each other so that we have three distinct graphemes: the base, first mark above the base, and second mark above the mark.
  glyphs, pos = shape(font, "\ue99\ueb5\uec9", options; info = (info = ShapingInfo()))
  @test glyphs == [0x000f, 0x003c, 0x0044]
  @test pos == [GlyphOffset(0, 0, 606, 0), GlyphOffset(24, 0, 0, 0), GlyphOffset(24, 339, 0, 0)]
  @test length(info.substitutions) == 0
  @test length(info.positionings) == 2
  @test info.positionings[1].type == POSITIONING_RULE_MARK_TO_BASE
  @test info.positionings[1].offsets == (glyphs[2] => GlyphOffset(24, 0, 0, 0))
  @test info.positionings[2].type == POSITIONING_RULE_MARK_TO_MARK
  @test info.positionings[2].offsets == (glyphs[3] => GlyphOffset(24, 339, 0, 0))

  # Hindi language, based on the Devanagari script. Seems to have lots of substitutions including contextual substitutions.
  file = first(google_font_files["notoserifdevanagari"])
  font = OpenTypeFont(file);
  options = ShapingOptions(tag"deva", tag"HIN ")
  glyphs, pos = shape(font, "ल\u094dल", options; info = (info = ShapingInfo()))
  @test_broken glyphs == [0x0116, 0x0053]
  @test_broken pos == [GlyphOffset(0, 0, 449, 0), GlyphOffset(0, 0, 655, 0)]

  # res = shape(font, "ल\u094dल", options)
  # res = hb_shape(file, "ल\u094dल", options)
  # res = shape(font, "\u0939\u093f\u0928\u094d\u0926\u0940", options)
  # expected = "हिन्दी"
end

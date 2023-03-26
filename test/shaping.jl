using Accessors: @set, @reset

@testset "Shaping" begin
  file = google_font_files["inter"][1]
  font = OpenTypeFont(file);
  options = ShapingOptions(tag"latn", tag"fra "; disabled_features = Set([tag"aalt", tag"case", tag"subs", tag"dnom", tag"numr"]))
  text = "=>"
  glyphs, positions = shape(font, text, options; info = (info = ShapingInfo()))
  @test_broken glyphs == [0x06b1]
  @test_broken positions == [GlyphOffset(0, 0, 2688, 0)]
  @test_broken length(info.substitutions) == 1
  @test_broken length(info.positionings) == 0
  @test_broken info.substitutions[1].type == SUBSTITUTION_RULE_LIGATURE
  hb_glyphs, hb_positions = hb_shape(file, text, options)
  @test_broken (glyphs, positions) == (hb_glyphs, hb_positions)

  # A font with kerning.
  file = google_font_files["notoserifgujarati"][1]
  font = OpenTypeFont(file);
  options = ShapingOptions(tag"latn", tag"fra ")
  text = "AV"
  glyphs, positions = shape(font, text, options; info = (info = ShapingInfo()))
  @test length(info.substitutions) == 0
  @test length(info.positionings) == 1
  @test info.positionings[1].type == POSITIONING_RULE_PAIR_ADJUSTMENT
  @test info.positionings[1].offsets == (glyphs => [GlyphOffset(0, 0, -40, 0), GlyphOffset(0, 0, 0, 0)])
  @test glyphs == [0x01d0, 0x0232]
  @test positions == [GlyphOffset(0, 0, 665, 0), GlyphOffset(0, 0, 675, 0)]
  hb_glyphs, hb_positions = hb_shape(file, text, options)
  @test glyphs == hb_glyphs
  # There is an advance difference of -40 on the X-axis for the first glyph.
  @test_broken positions == hb_positions

  # Cursive positioning rules.
  # TODO

  # Lao script & language. Has lots of diacritic marks for use with mark-to-base and mark-to-mark positioning tests.
  file = google_font_files["notoseriflao"][1]
  font = OpenTypeFont(file);
  options = ShapingOptions(tag"lao ", tag"dflt")

  # Simple mark-to-base positioning.

  text = "ສົ"

  glyphs, positions = shape(font, text, (@set options.enabled_features = Set([tag"aalt"])); info = (info = ShapingInfo()))
  @test length(info.substitutions) == 1
  @test length(info.positionings) == 1
  @test info.substitutions[1].type == SUBSTITUTION_RULE_ALTERNATE
  @test info.substitutions[1].replacement == (glyphs[2] => glyphs[2])
  @test info.positionings[1].type == POSITIONING_RULE_MARK_TO_BASE
  @test info.positionings[1].offsets == (glyphs[2] => GlyphOffset(-6, 0, 0, 0))
  @test glyphs == [0x001b, 0x003f]
  @test positions == [GlyphOffset(0, 0, 603, 0), GlyphOffset(-6, 0, 0, 0)]
  hb_glyphs, hb_positions = hb_shape(file, text, options)
  @test (glyphs, positions) == (hb_glyphs, hb_positions)

  text = "ກີບ"
  glyphs, positions = shape(font, text, options; info = (info = ShapingInfo()))
  @test length(info.substitutions) == 0
  @test length(info.positionings) == 1
  @test info.positionings[1].type == POSITIONING_RULE_MARK_TO_BASE
  @test info.positionings[1].offsets == (glyphs[2] => GlyphOffset(-4, 0, 0, 0))
  @test positions == [GlyphOffset(0, 0, 633, 0), GlyphOffset(-4, 0, 0, 0), GlyphOffset(0, 0, 635, 0)]
  @test glyphs == [0x0004, 0x003c, 0x0010]
  hb_glyphs, hb_positions = hb_shape(file, text, options)
  @test (glyphs, positions) == (hb_glyphs, hb_positions)

  # Mark-to-base and mark-to-mark positioning. The text may not be rendered correctly on an editor, but marks should neatly stack on top of each other so that we have three distinct graphemes: the base, first mark above the base, and second mark above the mark.
  text = "\ue99\ueb5\uec9"
  glyphs, positions = shape(font, text, options; info = (info = ShapingInfo()))
  @test length(info.substitutions) == 0
  @test length(info.positionings) == 2
  @test info.positionings[1].type == POSITIONING_RULE_MARK_TO_BASE
  @test info.positionings[1].offsets == (glyphs[2] => GlyphOffset(24, 0, 0, 0))
  @test info.positionings[2].type == POSITIONING_RULE_MARK_TO_MARK
  @test info.positionings[2].offsets == (glyphs[3] => GlyphOffset(24, 339, 0, 0))
  @test glyphs == [0x000f, 0x003c, 0x0044]
  @test positions == [GlyphOffset(0, 0, 606, 0), GlyphOffset(24, 0, 0, 0), GlyphOffset(24, 339, 0, 0)]
  hb_glyphs, hb_positions = hb_shape(file, text, options)
  @test glyphs == hb_glyphs
  @test_broken positions == hb_positions

  # Hindi language, based on the Devanagari script. Seems to have lots of substitutions including contextual substitutions.
  file = google_font_files["notoserifdevanagari"][1]
  font = OpenTypeFont(file);
  options = ShapingOptions(tag"deva", tag"HIN ")
  text = "ल\u094dल"
  glyphs, positions = shape(font, text, options; info = (info = ShapingInfo()))
  @test_broken glyphs == [0x0116, 0x0053]
  @test_broken positions == [GlyphOffset(0, 0, 449, 0), GlyphOffset(0, 0, 655, 0)]
  hb_glyphs, hb_positions = hb_shape(file, text, options)
  @test_broken (glyphs, positions) == (hb_glyphs, hb_positions)

  # res = shape(font, "ल\u094dल", options)
  # res = hb_shape(file, "ल\u094dल", options)
  # res = shape(font, "\u0939\u093f\u0928\u094d\u0926\u0940", options)
  # expected = "हिन्दी"
end

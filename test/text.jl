@testset "Text" begin
  for size in [FontSize(), FontSize(1.0), FontSize(1.0, reduce_to_fit = false)]
    @test sprint(show, MIME"text/plain"(), size) isa String
  end

  limits = TextLimits()
  for limits in [TextLimits(), TextLimits(1.0), TextLimits(1.0, 2.0)]
    @test sprint(show, MIME"text/plain"(), limits) isa String
  end

  @testset "Styling" begin
    text = styled"{red:Hello!}{red, italic, font = arial:Hi!}{bold:ho}ha"
    style_changes = extract_style_from_text(text)
    @test style_changes == [
      1 => CharacterStyle(color = RGBA(1f0, 0f0, 0f0, 1f0)),
      7 => CharacterStyle(color = RGBA(1f0, 0f0, 0f0, 1f0), slant = :italic, font = "arial"),
      10 => CharacterStyle(weight = :bold),
      12 => CharacterStyle(),
    ]

    # Handle Unicode symbols that span multiple codeunits.
    text = styled"𝟏{red:ຂ}{bold:3}"
    style_changes = extract_style_from_text(text)
    @test style_changes == [
      1 => CharacterStyle(),
      2 => CharacterStyle(color = RGBA(1f0, 0f0, 0f0, 1f0)),
      3 => CharacterStyle(weight = :bold),
    ]

    # Ignore unrecognized attributes and faces.
    text = styled"{bla = bla, wtf:Hello}"
    style_changes = extract_style_from_text(text)
    @test style_changes == [
      1 => CharacterStyle(),
    ]

    # Support a wide range of color specifications.

    ## Value is provided as an RGB value.
    text = styled"{color = #ffbb00:Hello!}"
    ((_, style), _...) = extract_style_from_text(text)
    @test style == CharacterStyle(; color = colorant"#ffbb00")

    ## Value is provided as an HSL string.
    ## Instead of using commas (which are reserved in the `@styled_str` macro), we allow semicolons.
    text = styled"{color = hsl(1; 20%; 50%):Hello!}"
    ((_, style), _...) = extract_style_from_text(text)
    @test style == CharacterStyle(; color = colorant"hsl(1, 20%, 50%)")

    ## Value is interpolated directly.
    color = colorant"hsl(1, 20%, 50%)"
    text = styled"{color = $color:Hello!}"
    ((_, style), _...) = extract_style_from_text(text)
    @test style == CharacterStyle(; color)

    ## More exotic spaces.
    color = Luv(50, -50, 60)
    text = styled"{color = $color:Hello!}"
    ((_, style), _...) = extract_style_from_text(text)
    @test style == CharacterStyle(; color)
  end

  file = google_font_files["inter"][1]
  font = OpenTypeFont(file);
  options = FontOptions(ShapingOptions(tag"latn", tag"fra "), FontSize(1/10; reduce_to_fit = false))
  t = Text("The brown fox jumps over the lazy dog.", TextOptions())
  ls = lines(t, [font => options])
  @test length(ls) == 1
  line = ls[1]
  @test length(line.glyphs) == length(t.chars)
  @test length(line.segments) == 1
  segment = line.segments[1]
  @test sprint(show, MIME"text/plain"(), segment) isa String
  @test segment.indices == eachindex(t.chars)
  box = boundingelement(t, [font => options])
  @test 0.0047 < box.min[1] < 0.0049
  @test -0.022 < box.min[2] < -0.021
  @test 1.81 < box.max[1] < 1.82
  @test 0.076 < box.max[2] < 0.077

  t = Text(styled"The {bold:brown} {red:fox {italic:jumps}} over the {italic:lazy} dog.", TextOptions())
  box2 = boundingelement(t, [font => options])
  @test box == box2
  line = only(lines(t, [font => options]))
  @test length(line.segments) == 8
  a, b, c, d, e, f, g, h = line.segments
  @test a.style == GlyphStyle()
  # TODO: Add weight to `GlyphStyle`.
  @test b.style == GlyphStyle(nothing, false, false)
  @test c.style == GlyphStyle()
  @test d.style == GlyphStyle(RGBA(1f0, 0f0, 0f0, 1f0), false, false)
  # TODO: Add slant to `GlyphStyle`.
  @test e.style == GlyphStyle(RGBA(1f0, 0f0, 0f0, 1f0), false, false)
  @test f.style == GlyphStyle()
  # TODO: Add slant to `GlyphStyle`.
  @test g.style == GlyphStyle(nothing, false, false)
  @test h.style == GlyphStyle()
end;

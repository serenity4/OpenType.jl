@testset "Text" begin
  for size in [FontSize(), FontSize(1.0), FontSize(1.0, reduce_to_fit = false)]
    @test sprint(show, MIME"text/plain"(), size) isa String
  end

  limits = TextLimits()
  for limits in [TextLimits(), TextLimits(1.0), TextLimits(1.0, 2.0)]
    @test sprint(show, MIME"text/plain"(), limits) isa String
  end

  @testset "Styling" begin
    text = styled"{red:Hello!}{red,italic:Hi!}{bold:ho}ha"
    style_changes = extract_style_from_text(text)
    @test style_changes == [
      1 => CharacterStyle(color = RGBA(1f0, 0f0, 0f0, 1f0)),
      7 => CharacterStyle(color = RGBA(1f0, 0f0, 0f0, 1f0), italic = true),
      10 => CharacterStyle(bold = true),
      12 => CharacterStyle(),
    ]
    text = styled"𝟏{red:ຂ}{bold:3}"
    style_changes = extract_style_from_text(text)
    @test style_changes == [
      1 => CharacterStyle(),
      2 => CharacterStyle(color = RGBA(1f0, 0f0, 0f0, 1f0)),
      3 => CharacterStyle(bold = true),
    ]
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
  @test 1.20 < box.max[1] < 1.21
  @test 0.076 < box.max[2] < 0.077

  t = Text(styled"The {bold:brown} {red:fox} {italic:jumps} over the {italic:lazy} dog.", TextOptions())
  @test length(lines(t, [font => options])) == 1
end;

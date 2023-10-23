@testset "Text" begin
  for size in [FontSize(), FontSize(1.0), FontSize(1.0, reduce_to_fit = false)]
    @test sprint(show, MIME"text/plain"(), size) isa String
  end

  limits = TextLimits()
  for limits in [TextLimits(), TextLimits(1.0), TextLimits(1.0, 2.0)]
    @test sprint(show, MIME"text/plain"(), limits) isa String
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
end;

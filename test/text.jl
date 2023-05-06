@testset "Text" begin
  file = google_font_files["inter"][1]
  font = OpenTypeFont(file);
  options = FontOptions(ShapingOptions(tag"latn", tag"fra "), 12)
  t = Text("The brown fox jumps over the lazy dog.", TextOptions())
  ls = lines(t, [font => options])
  @test length(ls) == 1
  line = ls[1]
  @test length(line.glyphs) == length(t.chars)
  @test length(line.segments) == 1
  segment = line.segments[1]
  @test segment.indices == eachindex(t.chars)
end;

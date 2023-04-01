@testset "Text" begin
  file = google_font_files["inter"][1]
  font = OpenTypeFont(file);
  options = FontOptions(ShapingOptions(tag"latn", tag"fra "), 12)
  t = Text("The brown fox jumps over the lazy dog.", TextOptions())
  ls = lines(t, [font => options])
  @test length(ls) == 1
  l = ls[1]
  @test length(l.glyphs) == length(t.chars)
  @test length(l.segments) == 1
end;

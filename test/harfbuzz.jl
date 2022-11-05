using OpenType, Test
using GeometryExperiments: Point

@testset "HarfBuzz" begin
  file = font_file("juliamono")
  options = ShapingOptions(tag"latn", tag"FRA ")
  glyphs, positions = hb_shape(file, "AVAA", options)
  @test getproperty.(positions, :advance) == repeat([Point(600, 0)], 4)
  @test glyphs == [4, 451, 4, 4]

  file = first(google_font_files["notoseriflao"])
  options = ShapingOptions(tag"lao ", tag"dflt")
  glyphs, positions = hb_shape(file, "\ue99\ueb5\uec9", options)
  @test length(positions) == length(glyphs) == 3
end

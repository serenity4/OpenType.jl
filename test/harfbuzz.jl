using OpenType, Test
using OpenType: hb_shape, hb_feature_t
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

  feature = hb_feature_t(tag4"liga", true)
  @test string(feature) == "liga"
  feature = hb_feature_t(tag4"liga", false)
  @test string(feature) == "-liga"

  # Feature selection. "calt" is enabled by default, which substitutes => with a single glyph.
  file = google_font_files["inter"][1]
  options = ShapingOptions(tag"latn", tag"FRA ")
  glyphs, positions = hb_shape(file, "=>", options)
  @test length(glyphs) == 1
  options = ShapingOptions(tag"latn", tag"FRA "; disabled_features = [tag4"calt"])
  glyphs, positions = hb_shape(file, "=>", options)
  @test length(glyphs) == 2
end;

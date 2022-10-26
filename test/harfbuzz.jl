using OpenType, Test

@testset "HarfBuzz" begin
  file = font_file("juliamono")
  options = ShapingOptions(tag"latn", tag"FRA ")
  infos, positions = hb_shape(file, "AVAA", options)
  @test getproperty.(positions, :x_advance) == repeat([600], 4)
  @test getproperty.(infos, :cluster) == collect(0:3)
  @test getproperty.(infos, :codepoint) == [4, 451, 4, 4]

  file = first(google_font_files["notoseriflao"])
  options = ShapingOptions(tag"lao ", tag"dflt")
  infos, positions = hb_shape(file, "\ue99\ueb5\uec9", options)
  @test length(positions) == length(infos) == 3
end

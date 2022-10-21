@testset "HarfBuzz" begin
  file = font_file("juliamono")
  infos, positions = hb_shape(file, "AVAA")
  @test getproperty.(positions, :x_advance) == repeat([600], 4)
  @test getproperty.(infos, :cluster) == collect(0:3)
  @test getproperty.(infos, :codepoint) == [4, 451, 4, 4]
end

using OpenType, Test
using OpenType: Tag, Tag2, Tag3, Tag4, Text, lines
using GeometryExperiments: Point2
using Accessors: @set, @reset
using HarfBuzz_jll: libharfbuzz

include("utils.jl")
include("libharfbuzz.jl")

@testset "OpenType.jl" begin
    include("tags.jl")
    include("scripts.jl")
    include("glyphs.jl")
    include("google_fonts.jl")
    include("harfbuzz.jl")
    include("shaping.jl")
    include("text.jl")
end;

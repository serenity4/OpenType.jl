using OpenType, Test

include("utils.jl")
include("libharfbuzz.jl")

@testset "OpenType.jl" begin
    include("tags.jl")
    include("glyphs.jl")
    include("google_fonts.jl")
    include("harfbuzz.jl")
    include("shaping.jl")
end;

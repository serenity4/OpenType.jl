using OpenType, Test

include("utils.jl")
include("libharfbuzz.jl")

@testset "OpenType.jl" begin
    include("tags.jl")
    include("glyphs.jl")
    include("google_fonts.jl")
    include("shaping.jl")
    include("harfbuzz.jl")
end;

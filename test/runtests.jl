using OpenType
using Test

include("utils.jl")
include("libharfbuzz.jl")

@testset "OpenType.jl" begin
    include("glyphs.jl")
    include("google_fonts.jl")
    include("harfbuzz.jl")
end;

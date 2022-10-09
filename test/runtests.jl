using OpenType
using Test

include("utils.jl")

@testset "OpenType.jl" begin
    include("glyphs.jl")
    include("google_fonts.jl")
end;

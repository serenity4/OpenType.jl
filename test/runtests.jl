using OpenType
using Test

const arial = joinpath(@__DIR__, "resources", "arial.ttf")
const juliamono = joinpath(@__DIR__, "resources", "JuliaMono-Regular.ttf")

OpenTypeFont(arial)
OpenTypeFont(juliamono)

@testset "OpenType.jl" begin
    # Write your tests here.
end

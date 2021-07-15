using OpenType
using OpenType: GlyphSimple, GlyphHeader, GlyphPoint, Glyph
using Test

const arial = joinpath(@__DIR__, "resources", "arial.ttf")
const juliamono = joinpath(@__DIR__, "resources", "JuliaMono-Regular.ttf")

OpenTypeFont(juliamono)
# OpenTypeFont(arial)

@testset "OpenType.jl" begin
    font = OpenTypeFont(juliamono)
    glyph = font.glyphs[64]
    @test glyph.header == GlyphHeader(1, 55, -15, 526, 732)
    @test glyph.data.contour_indices == [26]
    @test glyph.data.points == [
        GlyphPoint((186,-15), false),
        GlyphPoint((55,171), false),
        GlyphPoint((55,352), true),
        GlyphPoint((55,535), false),
        GlyphPoint((195,732), false),
        GlyphPoint((325,732), true),
        GlyphPoint((390,732), false),
        GlyphPoint((497,687), false),
        GlyphPoint((526,636), true),
        GlyphPoint((471,595), true),
        GlyphPoint((435,634), false),
        GlyphPoint((366,660), false),
        GlyphPoint((322,660), true),
        GlyphPoint((230,660), false),
        GlyphPoint((149,503), false),
        GlyphPoint((149,357), true),
        GlyphPoint((149,211), false),
        GlyphPoint((225,60), false),
        GlyphPoint((319,60), true),
        GlyphPoint((370,60), false),
        GlyphPoint((445,95), false),
        GlyphPoint((472,135), true),
        GlyphPoint((526,87), true),
        GlyphPoint((494,35), false),
        GlyphPoint((386,-15), false),
        GlyphPoint((318,-15), true),
    ]
end


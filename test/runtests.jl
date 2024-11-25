using OpenType, Test
using OpenType: Text, lines, extract_style_from_text, CharacterStyle, hb_shape, Vec, Vec2, cm
using BinaryParsingTools
using Accessors: @set, @reset
using StyledStrings
using Colors
using Meshes: Point, coords

include("utils.jl")

@testset "OpenType.jl" begin
    include("tags.jl")
    include("scripts.jl")
    include("glyphs.jl")
    include("google_fonts.jl")
    include("harfbuzz.jl")
    include("shaping.jl")
    include("text.jl")
end;

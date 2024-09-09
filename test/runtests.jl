using OpenType, Test
using OpenType: Text, lines, extract_style_from_text, CharacterStyle, hb_shape
using BinaryParsingTools
using GeometryExperiments: Point2
using Accessors: @set, @reset
using StyledStrings
using Colors

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

module OpenType

using Dates
using SwapStreams
using GeometryExperiments

import Base: ==, isless, &, |, in, xor

include("bitmasks.jl")
include("parse.jl")
include("glyphs.jl")
include("font.jl")
include("collection.jl")

export
        TableRecord,
        FontHeader,
        MaximumProfile,
        CharToGlyph,

        # glyphs
        Glyph, GlyphHeader, GlyphData,
        GlyphSimple, GlyphPoint,
        uncompress, normalize, curves,
        glyph_index,

        OpenTypeFont,
        OpenTypeCollection


end

module OpenType

using Dates
using SwapStreams
using GeometryExperiments
using .Meta: isexpr

import Base: ==, isless, &, |, in, xor

const Optional{T} = Union{T,Nothing}

include("bitmasks.jl")
include("parse.jl")
include("glyphs.jl")
include("data.jl")
include("collection.jl")
# include("text.jl")

export
        TableRecord,
        FontHeader,
        MaximumProfile,
        CharToGlyph,

        # glyphs
        Glyph, GlyphHeader, GlyphData,
        SimpleGlyph, GlyphPoint,
        uncompress, normalize, curves,
        glyph_index,

        OpenTypeData,
        OpenTypeCollection


end

module OpenType

using Dates
using SwapStreams
using GeometryExperiments
using ColorTypes: RGBA
using Accessors: @set
using .Meta: isexpr
using BitMasks

const GlyphID = UInt16
const GlyphOffset = Int16
const Class = UInt16

const Optional{T} = Union{T,Nothing}
const VERSION16DOT16 = UInt32
version_16_dot_16(version::VERSION16DOT16) = VersionNumber(version >> 16 + (version & 0x0000ffff) >> 8)
"16-bit signed fixed number with the low 14 bits of fraction (2.14)."
const F2DOT14 = Int16
const LONGDATETIME = Int64
const Fixed = UInt32
"4-byte string."
const Tag = String

include("error.jl")
include("parse.jl")
include("abstractions.jl")
include("data.jl")
include("glyphs.jl")
include("font.jl")
include("char_to_glyph.jl")
include("text.jl")

export
        Glyph,
        SimpleGlyphTable,

        OpenTypeData, OpenTypeFont


end

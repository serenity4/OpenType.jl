module OpenType

using Dates
using SwapStreams
using GeometryExperiments
using .Meta: isexpr

const Optional{T} = Union{T,Nothing}
const VERSION16DOT16 = UInt32
version_16_dot_16(version::VERSION16DOT16) = VersionNumber(version >> 16 + (version & 0x0000ffff) >> 8)
"16-bit signed fixed number with the low 14 bits of fraction (2.14)."
const F2DOT14 = Int16

include("bitmasks.jl")
include("error.jl")
include("parse.jl")
include("glyphs.jl")
include("data.jl")
include("collection.jl")
# include("text.jl")

export
        Glyph,
        SimpleGlyph,
        uncompress, normalize, curves,

        OpenTypeData,
        OpenTypeCollection


end

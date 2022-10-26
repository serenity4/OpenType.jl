module OpenType

using Dates
using SwapStreams
using GeometryExperiments
using ColorTypes: RGBA
using Accessors: @set
using .Meta: isexpr
using BitMasks

"0-based glyph identifier, often used as index with relevant data structures."
const GlyphID = UInt16
const GlyphIDOffset = Int16
"0-based glyph class identifier, often used as index with relevant data structures."
const ClassID = UInt16

const Optional{T} = Union{T,Nothing}
const VERSION16DOT16 = UInt32
version_16_dot_16(version::VERSION16DOT16) = VersionNumber(version >> 16 + (version & 0x0000ffff) >> 8)
"16-bit signed fixed number with the low 14 bits of fraction (2.14)."
const F2DOT14 = Int16
f2dot14_to_float(x::F2DOT14) = Float64(x >> 14) + 1e-14 * x << 2
const LONGDATETIME = Int64
const Fixed = UInt32

include("tags.jl")
include("traced_io.jl")
include("error.jl")
include("options.jl")
include("parse.jl")
include("data.jl")
include("glyphs.jl")
include("abstractions.jl")
include("positioning.jl")
include("substitutions.jl")
include("font.jl")
include("char_to_glyph.jl")
include("shaping.jl")
include("text.jl")

export GlyphID, GlyphOffset, OpenTypeData, OpenTypeFont, FontOptions, TextOptions, text_glyphs, glyph_offsets, positioning_rules, @tag_str, @tag2_str, @tag3_str, @tag4_str, shape, ShapingOptions, Direction, DIRECTION_LEFT_TO_RIGHT, DIRECTION_RIGHT_TO_LEFT, DIRECTION_TOP_TO_BOTTOM, DIRECTION_BOTTOM_TO_TOP


end

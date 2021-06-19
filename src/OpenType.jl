module OpenType

using Dates
using SwapStreams

import Base: ==, isless, &, |, in, xor

include("bitmasks.jl")
include("types.jl")
include("parser.jl")

export
        OpenTypeFont,
        OpenTypeCollection


end

module OpenType

using Dates
using SwapStreams
using GeometryExperiments

import Base: ==, isless, &, |, in, xor

include("bitmasks.jl")
include("types.jl")
include("parser.jl")

include("extract.jl")

export
        OpenTypeFont,
        OpenTypeCollection


end

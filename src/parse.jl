"""
Return an IO that will always read in the right endianness.
"""
function correct_endianess(io::IO)
    sfnt = Base.peek(io, UInt32)
    if sfnt == 0x00000100
        SwapStream(io)
    else
        io
    end
end

version_16_dot_16(version::UInt32) = VersionNumber(version >> 16 + (version & 0x0000ffff) >> 8)

include("parsing/table_records.jl")
include("parsing/font_header.jl")
include("parsing/maximum_profile.jl")
include("parsing/char_to_glyph.jl")

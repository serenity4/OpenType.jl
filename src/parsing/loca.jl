struct IndexToLocation
    offsets::Union{Vector{UInt16}, Vector{UInt32}}
end

function Base.read(io::IO, ::Type{IndexToLocation}, T, nglyphs)
    IndexToLocation([read(io, T) for _ in 0:nglyphs])
end

function Base.read(io::IO, ::Type{IndexToLocation}, maxp::MaximumProfile, head::FontHeader)
    head.index_to_loc_format in (0, 1) || error("Index to location format must be either 0 or 1.")
    if iszero(head.index_to_loc_format)
        read(io, IndexToLocation, UInt16, maxp.nglyphs)
    else
        read(io, IndexToLocation, UInt32, maxp.nglyphs)
    end
end

function glyph_ranges(loca::IndexToLocation)
    ranges = Vector{UnitRange{UInt32}}(undef, length(loca.offsets) - 1)
    for i in 1:length(ranges)
        range = if eltype(loca.offsets) === UInt16
            UInt32(2 * loca.offsets[i]):UInt32(2 * loca.offsets[i+1])
        else
            loca.offsets[i]:loca.offsets[i+1]
        end
        ranges[i] = range
    end
    ranges
end

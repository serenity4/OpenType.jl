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
    [start:finish for (start, finish) in zip(loca.offsets[1:end-1], loca.offsets[2:end])]
end

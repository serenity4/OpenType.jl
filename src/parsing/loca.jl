struct IndexToLocation{T}
    offsets::Vector{T}
end

function Base.parse(io::IO, ::Type{IndexToLocation{T}}, maxp::MaximumProfile) where {T}
    offsets = map(0:maxp.nglyphs) do i
        read(io, T)
    end
    IndexToLocation{T}(offsets)
end

function Base.parse(io::IO, ::Type{IndexToLocation}, maxp::MaximumProfile, head::FontHeader)
    head.index_to_loc_format in (0, 1) || error("Index to location format must be either 0 or 1.")
    T = head.index_to_loc_format == 0 ? UInt16 : UInt32
    parse(io, IndexToLocation{T}, maxp)
end

function glyph_ranges(loca::IndexToLocation)
    [start:finish for (start, finish) in zip(loca.offsets[1:end-1], loca.offsets[2:end])]
end

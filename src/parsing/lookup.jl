abstract type LookupTable end

@serializable struct LookupListTable
    lookup_count::UInt16
    lookup_offsets::Vector{UInt16} => lookup_count
    lookup_tables::Vector{LookupTable} => [reat_at(io, LookupTable, offset; start = __origin__) for offset in lookup_offsets]
end

function Base.read(io::IO, ::Type{LookupListTable}, @nospecialize(T))
    __origin__ = position(io)
    lookup_count = read(io, UInt16)
    lookup_offsets = [read(io, UInt16) for _ in 1:lookup_count]
    LookupListTable(lookup_count, lookup_offsets, [read_at(io, T, offset; start = __origin__) for offset in lookup_offsets])
end

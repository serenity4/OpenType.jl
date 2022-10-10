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

@bitmask LookupFlag::UInt16 begin
    LOOKUP_RIGHT_TO_LEFT             = 0x0001
    LOOKUP_IGNORE_BASE_GLYPHS        = 0x0002
    LOOKUP_IGNORE_LIGATURES          = 0x0004
    LOOKUP_IGNORE_MARKS              = 0x0008
    LOOKUP_USE_MARK_FILTERING_SET    = 0x0010
    LOOKUP_RESERVED                  = 0x00e0
    LOOKUP_MARK_ATTACHMENT_TYPE_MASK = 0xff00
end

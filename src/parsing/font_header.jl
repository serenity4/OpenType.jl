struct FontHeader
    flags::UInt16
    units_per_em::UInt16
    created::DateTime
    modified::DateTime
    xmin::Int16
    ymin::Int16
    xmax::Int16
    ymax::Int16
    mac_style::UInt16
    min_readable_size::Int16
    font_direction_hint::Int16
    index_to_loc_format::Int16
    glyph_data_format::Int16
end

function Base.read(io::IO, ::Type{FontHeader})
    skip(io, 12)
    read(io, UInt32) == 0x5f0f3cf5 || error("Invalid magic number in font header")
    FontHeader(
        read(io, UInt16),
        read(io, UInt16),
        DateTime(1904, 01, 01) + Dates.Second(read(io, Int64)),
        DateTime(1904, 01, 01) + Dates.Second(read(io, Int64)),
        (read(io, T) for T in fieldtypes(FontHeader)[5:end])...
    )
end

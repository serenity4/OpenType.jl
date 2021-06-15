function parse(::Type{TableRecord}, io::IO, read)
    tag = transcode(String, [read(io, UInt8) for _ in 1:4])
    TableRecord(tag, read(io, UInt32), read(io, UInt32), read(io, UInt32))
end

"""
Pad a table length so that it respects the four-byte
alignment requirements of the OpenType format.
"""
function padded_length(tr::TableRecord)
    4 * cld(tr.length, 4)
end

function checksum_head(io::IO, tr::TableRecord, read, adjustment)
    pos = position(io)
    sum = UInt32(0)
    seek(io, 0)
    i = 0
    while !eof(io)
        sum += read(io, UInt32)
    end
    seek(io, pos)
    sum -= adjustment
    0xb1b0afba - sum
end

function checksum(io::IO, tr::TableRecord, read)
    pos = position(io)
    sum = UInt32(0)
    seek(io, tr.offset)
    for _ in 1:cld(tr.length, 4)
        sum += read(io, UInt32)
    end
    seek(io, pos)
    sum
end

function correct_endianness(io::IO)
    sfnt = Base.peek(io, UInt32)
    if sfnt == 0x00000100
        swap_endianness = ENDIAN_BOM == 0x04030201 ? ntoh : ltoh
        # (io, T) -> swap_endianness(Base.read(io, T))
        (io, T) -> swap_endianness(Base.read(io, T))
    else
        (io, T) -> Base.read(io, T)
    end
end

version_16_dot_16(version::UInt32) = VersionNumber(version >> 16 + (version & 0x0000ffff) >> 8)

"""
Parse an OpenType font from `io`.

A specification for OpenType font files is available
at https://docs.microsoft.com/en-us/typography/opentype/spec/otff
"""
function OpenTypeFont(io::IO)
    read = correct_endianness(io)
    sfnt = read(io, UInt32)
    sfnt in (0x00010000, 0x4F54544F) || error("Invalid format: unknown SFNT version. Expected 0x00010000 or 0x4F54544F.")
    ntables = read(io, UInt16)
    search_range = read(io, UInt16)
    entry_selector = read(io, UInt16)
    range_shift = read(io, UInt16)
    table_records = map(_ -> parse(TableRecord, io, read), 1:ntables)
    foreach(table_records) do tr
        msg = "Invalid checksum for table $(tr.tag)"
        if tr.tag == "head"
            pos = position(io)
            seek(io, tr.offset + 8)
            adjustment = read(io, UInt32)
            seek(io, pos)
            checksum_head(io, tr, read, adjustment) == adjustment || error(msg)
        else
            checksum(io, tr, read) == tr.checksum || error(msg)
        end
    end
    table_mappings = Dict(tr.tag => tr for tr in table_records)

    println.(table_records)
    seek(io, table_mappings["maxp"].offset)
    maxprofile = MaximumProfile(
        version_16_dot_16(read(io, UInt32)),
        (read(io, T) for T in fieldtypes(MaximumProfile)[2:end])...
    )
    seek(io, table_mappings["head"].offset)
    skip(io, 12)
    read(io, UInt32) == 0x5F0F3CF5 || error("Invalid magic number in font header")
    FontHeader(
        read(io, UInt16),
        read(io, UInt16),
        DateTime(1904, 01, 01) + Dates.Second(read(io, Int64)),
        DateTime(1904, 01, 01) + Dates.Second(read(io, Int64)),
        (read(io, T) for T in fieldtypes(FontHeader)[5:end])...
    )
end

OpenTypeFont(file::String) = open(io -> OpenTypeFont(io), file)

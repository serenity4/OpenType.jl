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

    # head
    seek(io, table_mappings["head"].offset)
    skip(io, 12)
    read(io, UInt32) == 0x5f0f3cf5 || error("Invalid magic number in font header")
    head = FontHeader(
        read(io, UInt16),
        read(io, UInt16),
        DateTime(1904, 01, 01) + Dates.Second(read(io, Int64)),
        DateTime(1904, 01, 01) + Dates.Second(read(io, Int64)),
        (read(io, T) for T in fieldtypes(FontHeader)[5:end])...
    )

    # maximum profile
    seek(io, table_mappings["maxp"].offset)
    maxp = MaximumProfile(
        version_16_dot_16(read(io, UInt32)),
        (read(io, T) for T in fieldtypes(MaximumProfile)[2:end])...
    )

    # character to glyph map
    seek(io, table_mappings["cmap"].offset)
    skip(io, 2)
    ntables = read(io, UInt16)
    records = map(1:ntables) do _
        EncodingRecord(
            PlatformID(read(io, UInt16)),
            (read(io, T) for T in fieldtypes(EncodingRecord)[2:3])...
        )
    end
    d = Dict()
    foreach(records) do rec
        seek(io, table_mappings["cmap"].offset + rec.subtable_offset)
        format = read(io, UInt16)
        table = if format == 0
            skip(io, 4)
            ByteEncodingTable([read(io, UInt8) for _ in 1:256])
        elseif format == 12
            skip(io, 10)
            ngroups = read(io, UInt32)
            groups = map(1:ngroups) do i
                SequentialMapGroup(
                    read(io, UInt32):read(io, UInt32),
                    read(io, UInt32),
                )
            end
            SegmentedCoverage(groups)
        else
            return
        end
        d[format] = table
    end
    cmap = CharToGlyph(records, d)
end

OpenTypeFont(file::String) = open(io -> OpenTypeFont(io), file)

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

function checksum_head(io::IO, tr::TableRecord, adjustment)
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

function checksum(io::IO, tr::TableRecord)
    pos = position(io)
    sum = UInt32(0)
    seek(io, tr.offset)
    for _ in 1:cld(tr.length, 4)
        sum += read(io, UInt32)
    end
    seek(io, pos)
    sum
end

"""
Given the input IO, return a read function
that will convert the input to the right endianness.
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

"""
Parse an OpenType font from `io`.

A specification for OpenType font files is available
at https://docs.microsoft.com/en-us/typography/opentype/spec/otff
"""
function OpenTypeFont(io::IO)
    io = correct_endianess(io)
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
            checksum_head(io, tr, adjustment) == adjustment || error(msg)
        else
            checksum(io, tr) == tr.checksum || error(msg)
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

    seek(io, table_mappings["loca"].offset)
    head.index_to_loc_format in (0, 1) || error("Index to location format must be either 0 or 1.")
    T = head.index_to_loc_format == 0 ? UInt16 : UInt32
    goffsets = map(0:maxp.nglyphs) do i
        read(io, T)
    end
    glengths = goffsets[begin+1:end] .- goffsets[begin:end-1]
    glyphs = map(goffsets[begin:end-1]) do offset
        seek(io, table_mappings["glyf"].offset + offset)
        header = GlyphHeader(
            (read(io, T) for T in fieldtypes(GlyphHeader))...
        )
        data = if header.ncontours ≠ -1
            end_contour_points = [read(io, UInt16) for _ in 1:header.ncontours]

            # convert to 1-based indexing
            end_contour_points .+= 1

            instlength = read(io, UInt16)
            insts = [read(io, UInt8) for _ in 1:instlength]
            end_idx = end_contour_points[end]
            flags = SimpleGlyphFlag[]
            while length(flags) < end_idx
                flag = SimpleGlyphFlag(read(io, UInt8))
                push!(flags, flag)
                if REPEAT_FLAG_BIT in flag
                    repeat_count = read(io, UInt8)
                    append!(flags, (flag for _ in 1:repeat_count))
                end
            end
            xs = Int[]
            foreach(flags) do flag
                x = if X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT in flag && X_SHORT_VECTOR_BIT ∉ flag
                    val = isempty(xs) ? 0 : last(xs)
                    push!(xs, val)
                    return
                elseif X_SHORT_VECTOR_BIT in flag
                    val = Int(read(io, UInt8))
                    X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT in flag ? val : -val
                elseif X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT ∉ flag && X_SHORT_VECTOR_BIT ∉ flag
                    read(io, Int16)
                end
                push!(xs, x + (isempty(xs) ? 0 : last(xs)))
            end

            ys = Int[]
            foreach(flags) do flag
                y = if Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT in flag && Y_SHORT_VECTOR_BIT ∉ flag
                    val = isempty(ys) ? 0 : last(ys)
                    push!(ys, val)
                    return
                elseif Y_SHORT_VECTOR_BIT in flag
                    val = Int(read(io, UInt8))
                    Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT in flag ? val : -val
                elseif Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT ∉ flag && Y_SHORT_VECTOR_BIT ∉ flag
                    read(io, Int16)
                end
                push!(ys, y + (isempty(ys) ? 0 : last(ys)))
            end
            GlyphSimple(
                end_contour_points,
                GlyphPoint.(collect(zip(xs, ys)), map(Base.Fix1(in, ON_CURVE_POINT_BIT), flags)),
            )
        end
        Glyph(header, data)
    end

    OpenTypeFont(cmap, head, nothing, nothing, maxp, nothing, nothing, nothing, glyphs)
end

OpenTypeFont(file::String) = open(io -> OpenTypeFont(io), file)

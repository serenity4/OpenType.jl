struct OpenTypeFont
    cmap::CharToGlyph
    head::FontHeader
    hhea
    hmtx
    maxp::MaximumProfile
    name
    os_2
    post
    glyphs::Vector{Glyph}
end

"""
Parse an OpenType font from `io`.

A specification for OpenType font files is available
at https://docs.microsoft.com/en-us/typography/opentype/spec/otff
"""
function Base.parse(io::IO, ::Type{OpenTypeFont})
    io = correct_endianess(io)
    sfnt = read(io, UInt32)
    sfnt in (0x00010000, 0x4F54544F) || error("Invalid format: unknown SFNT version. Expected 0x00010000 or 0x4F54544F.")
    ntables = read(io, UInt16)
    search_range = read(io, UInt16)
    entry_selector = read(io, UInt16)
    range_shift = read(io, UInt16)
    table_records = map(_ -> parse(TableRecord, io), 1:ntables)
    validate(io, table_records)
    table_mappings = Dict(tr.tag => tr for tr in table_records)

    # head
    seek(io, table_mappings["head"].offset)
    head = parse(io, FontHeader)

    # maximum profile
    seek(io, table_mappings["maxp"].offset)
    maxp = parse(io, MaximumProfile)

    # character to glyph map
    seek(io, table_mappings["cmap"].offset)
    cmap = parse(io, table_mappings, CharToGlyph)

    # glyphs
    seek(io, table_mappings["loca"].offset)
    glyphs = parse_glyphs(io, head, maxp, table_mappings)

    OpenTypeFont(cmap, head, nothing, nothing, maxp, nothing, nothing, nothing, glyphs)
end

OpenTypeFont(file::AbstractString) = open(Base.Fix2(parse, OpenTypeFont), file)

Base.getindex(font::OpenTypeFont, char::Char) = Glyph(font, char)

function Glyph(font::OpenTypeFont, char::Char; pick_table=first)
    tables = values(font.cmap.tables)
    table = pick_table(tables)
    if table isa ByteEncodingTable
        offset = table.glyph_id_array[UInt8(char)]
    elseif table isa SegmentedCoverage
        offset = 0
        char_uint = UInt32(char)
        for group in table.groups
            if char_uint in group.char_range
                offset = group.start_glyph_id + (char_uint - group.char_range.start)
                break
            end
        end
    else
        error("Unsupported table type $(typeof(table))")
    end
    font.glyphs[1 + offset]
end

struct OpenTypeFont
    cmap::CharToGlyph
    head::FontHeader
    hhea::HorizontalHeader
    hmtx::HorizontalMetrics
    vhea::VerticalHeader
    vmtx::VerticalMetrics
    maxp::MaximumProfile
    name
    os_2
    post
    glyphs::Vector{Union{Nothing,Glyph}}
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
    nav = TableNavigationMap(table_records)
    validate(io, nav)

    # head
    head = read_table(Base.Fix2(parse, FontHeader), io, nav["head"])

    # maximum profile
    maxp = read_table(Base.Fix2(parse, MaximumProfile), io, nav["maxp"])

    # character to glyph map
    cmap = read_table(io -> parse(io, nav, CharToGlyph), io, nav["cmap"])

    # index to location
    loca = read_table(io -> parse(io, IndexToLocation, maxp, head), io, nav["loca"])

    # glyphs
    glyphs = read_table(io -> read_glyphs(io, head, maxp, nav, loca), io, nav["glyf"])

    # metrics
    hhea = read_table(Base.Fix2(parse, HorizontalHeader), io, nav["hhea"])
    vhea = read_table(Base.Fix2(parse, VerticalHeader), io, nav["vhea"])
    hmtx = read_table(io -> parse(io, HorizontalMetrics, hhea, maxp), io, nav["hmtx"])
    vmtx = read_table(io -> parse(io, VerticalMetrics, vhea, maxp), io, nav["vmtx"])

    OpenTypeFont(cmap, head, hhea, hmtx, vhea, vmtx, maxp, nothing, nothing, nothing, glyphs)
end

OpenTypeFont(file::AbstractString) = open(Base.Fix2(parse, OpenTypeFont), file)

Base.getindex(font::OpenTypeFont, char::Char) = Glyph(font, char)

function glyph_index(font::OpenTypeFont, char::Char; pick_table=first)
    tables = values(font.cmap.tables)
    table = pick_table(tables)
    if table isa ByteEncodingTable
        return table.glyph_id_array[UInt8(char)] + 1
    elseif table isa SegmentedCoverage
        offset = 0
        char_uint = UInt32(char)
        for group in table.groups
            if char_uint in group.char_range
                return group.start_glyph_id + (char_uint - group.char_range.start) + 1
            end
        end
    else
        error("Unsupported table type $(typeof(table))")
    end
end

Glyph(font::OpenTypeFont, char::Char; pick_table=first) = font.glyphs[glyph_index(font, char; pick_table)]

function GeometryExperiments.boundingelement(glyph::Glyph)
    Scaling(glyph.header.xmax - glyph.header.xmin, glyph.header.ymax - glyph.header.ymin)(PointSet(HyperCube(0.5), Point{2,Float64}))
end

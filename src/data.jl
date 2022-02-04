struct OpenTypeData
    nav::TableNavigationMap
    cmap::CharacterToGlyphIndexMappingTable
    head::FontHeader
    hhea::HorizontalHeader
    hmtx::HorizontalMetrics
    vhea::VerticalHeader
    vmtx::VerticalMetrics
    maxp::MaximumProfile
    fvar::Optional{FontVariationsTable}
    avar::Optional{AxisVariationsTable}
    name
    os_2
    post
    glyphs::Vector{Union{Nothing,Glyph}}
end

"""
Read OpenType font data from `io`.

A specification for OpenType font files is available
at https://docs.microsoft.com/en-us/typography/opentype/spec/otff
"""
function Base.read(io::IO, ::Type{OpenTypeData})
    io = IOBuffer(read(io))
    io = correct_endianess(io)
    sfnt = read(io, UInt32)
    sfnt in (0x00010000, 0x4F54544F) || error("Invalid format: unknown SFNT version (expected 0x00010000 or 0x4F54544F). The provided IO may not describe an OpenType font, or may describe one that is not conform to the OpenType specification.")
    ntables = read(io, UInt16)
    search_range = read(io, UInt16)
    entry_selector = read(io, UInt16)
    range_shift = read(io, UInt16)
    table_records = map(_ -> read(io, TableRecord), 1:ntables)
    nav = TableNavigationMap(table_records)
    validate(io, nav)

    # head
    head = read_table(Base.Fix2(read, FontHeader), io, nav["head"])

    # maximum profile
    maxp = read_table(Base.Fix2(read, MaximumProfile), io, nav["maxp"])

    # character to glyph map
    cmap = read_table(Base.Fix2(read, CharacterToGlyphIndexMappingTable), io, nav["cmap"])

    # index to location
    loca = read_table(io -> read(io, IndexToLocation, maxp, head), io, nav["loca"])

    # glyphs
    glyphs = read_table(io -> read_glyphs(io, head, maxp, nav, loca), io, nav["glyf"])

    # metrics
    hhea = read_table(Base.Fix2(read, HorizontalHeader), io, nav["hhea"])
    vhea = read_table(Base.Fix2(read, VerticalHeader), io, nav["vhea"])
    hmtx = read_table(io -> read(io, HorizontalMetrics, hhea, maxp), io, nav["hmtx"])
    vmtx = read_table(io -> read(io, VerticalMetrics, vhea, maxp), io, nav["vmtx"])

    # font variations
    fvar = read_table(Base.Fix2(read, AxisVariationsTable), io, nav, "fvar")

    # axis variations
    avar = read_table(Base.Fix2(read, AxisVariationsTable), io, nav, "avar")

    OpenTypeData(nav, cmap, head, hhea, hmtx, vhea, vmtx, maxp, fvar, avar, nothing, nothing, nothing, glyphs)
end

OpenTypeData(file::AbstractString) = open(Base.Fix2(read, OpenTypeData), file)

Base.getindex(data::OpenTypeData, char::Char) = Glyph(data, char)

function glyph_index(data::OpenTypeData, char::Char; pick_table=first)
    tables = values(data.cmap.tables)
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

Glyph(data::OpenTypeData, char::Char; pick_table=first) = data.glyphs[glyph_index(data, char; pick_table)]

function GeometryExperiments.boundingelement(glyph::Glyph)
    Scaling(glyph.header.xmax - glyph.header.xmin, glyph.header.ymax - glyph.header.ymin)(PointSet(HyperCube(0.5), Point{2,Float64}))
end

@serializable struct TableDirectory
    snft_version::UInt32
    num_tables::UInt16
    search_range::UInt16
    entry_selector::UInt16
    range_shift::UInt16
    table_records::Vector{TableRecord} => num_tables
end

struct OpenTypeData
    table_directory::TableDirectory
    cmap::CharacterToGlyphIndexMappingTable
    head::FontHeader
    hhea::HorizontalHeader
    hmtx::HorizontalMetrics
    maxp::MaximumProfile
    name # TODO
    os_2 # TODO
    post # TODO
    vhea::Optional{VerticalHeader}
    vmtx::Optional{VerticalMetrics}

    # TrueType outlines.
    loca::Optional{IndexToLocation}
    glyf::Optional{GlyphTable}

    # Font variations.
    avar::Optional{AxisVariationsTable}
    fvar::Optional{FontVariationsTable}
end

"""
Read OpenType font data from `io`.

A specification for OpenType font files is available
at https://docs.microsoft.com/en-us/typography/opentype/spec/otff
"""

Base.read(io::IOBuffer, ::Type{OpenTypeData}) = read(correct_endianess(io), OpenTypeData)
Base.read(io::IO, ::Type{OpenTypeData}) = read(IOBuffer(read(io)), OpenTypeData)

function Base.read(io::SwapStream, ::Type{OpenTypeData})
    sfnt = peek(io, UInt32)
    sfnt in (0x00010000, 0x4F54544F) || error_invalid_font("Invalid format: unknown SFNT version (expected 0x00010000 or 0x4F54544F). The provided IO may not describe an OpenType font, or may describe one that is not conform to the OpenType specification.")
    table_directory = read(io, TableDirectory)
    nav = TableNavigationMap(table_directory.table_records)
    validate(io, nav)

    cmap = read_table(Base.Fix2(read, CharacterToGlyphIndexMappingTable), io, nav, "cmap")::CharacterToGlyphIndexMappingTable
    head = read_table(Base.Fix2(read, FontHeader), io, nav, "head")::FontHeader
    hhea = read_table(Base.Fix2(read, HorizontalHeader), io, nav, "hhea")::HorizontalHeader
    maxp = read_table(Base.Fix2(read, MaximumProfile), io, nav, "maxp")::MaximumProfile
    hmtx = read_table(io -> read(io, HorizontalMetrics, hhea, maxp), io, nav, "hmtx")::HorizontalMetrics

    # TrueType outlines.
    loca = read_table(io -> read(io, IndexToLocation, maxp, head), io, nav, "loca")
    glyf = read_table(io -> read(io, GlyphTable, head, maxp, nav, loca), io, nav, "glyf")
    vhea = read_table(Base.Fix2(read, VerticalHeader), io, nav, "vhea")
    vmtx = read_table(io -> read(io, VerticalMetrics, vhea, maxp), io, nav, "vmtx")

    # Font variations.
    avar = read_table(Base.Fix2(read, AxisVariationsTable), io, nav, "avar")
    fvar = read_table(Base.Fix2(read, FontVariationsTable), io, nav, "fvar")

    OpenTypeData(table_directory, cmap, head, hhea, hmtx, maxp, nothing, nothing, nothing, vhea, vmtx, loca, glyf, avar, fvar)
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

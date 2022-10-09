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

    # Advanced typographic tables.
    gpos::Optional{GlyphPositioningTable}
end

"""
Read OpenType font data from `io`.

A specification for OpenType font files is available
at https://docs.microsoft.com/en-us/typography/opentype/spec/otff
"""

Base.read(io::IOBuffer, ::Type{OpenTypeData}) = read(correct_endianess(io), OpenTypeData)
Base.read(io::IO, ::Type{OpenTypeData}) = read(IOBuffer(read(io)), OpenTypeData)

function Base.read(io::Union{SwapStream,TracedIO{<:SwapStream}}, ::Type{OpenTypeData})
    table_directory, nav = TableNavigationMap(io)
    read(io, OpenTypeData, table_directory, nav)
end

function TableNavigationMap(io::Union{SwapStream,TracedIO{<:SwapStream}})
    sfnt = peek(io, UInt32)
    sfnt in (0x00010000, 0x4F54544F) || error_invalid_font("Invalid format: unknown SFNT version (expected 0x00010000 or 0x4F54544F). The provided IO may not describe an OpenType font, or may describe one that is not conform to the OpenType specification.")
    table_directory = read(io, TableDirectory)
    nav = TableNavigationMap(table_directory.table_records)
    ret = verify_checksums(io, nav)
    isa(ret, InvalidFontException) && @warn(ret.msg)
    @debug "Available tables: $(join(getproperty.(values(nav.map), :tag), ", "))"
    table_directory, nav
end

function Base.read(io::Union{SwapStream,TracedIO{<:SwapStream}}, ::Type{OpenTypeData}, table_directory::TableDirectory, nav::TableNavigationMap)
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

    # Advanced typographic tables.
    gpos = read_table(Base.Fix2(read, GlyphPositioningTable), io, nav, "GPOS")

    OpenTypeData(table_directory, cmap, head, hhea, hmtx, maxp, nothing, nothing, nothing, vhea, vmtx, loca, glyf, avar, fvar, gpos)
end

function OpenTypeData(file::AbstractString; debug = false)
    open(file) do io
        io = correct_endianess(IOBuffer(read(io)))
        if !debug
            read(io, OpenTypeData)
        else
            io = TracedIO(io)
            table_directory, nav = TableNavigationMap(io)
            read(io, OpenTypeData, table_directory, nav)
            
            # TODO: Provide debug information in case of failure based on parsed ranges.
            # try
            #   read(io, OpenTypeData, nav, table_directory)
            # catch e
            #     isa(e, EOFError) || rethrow()
            #     error_hints(io)
            #     rethrow()
            # end
        end
    end
end

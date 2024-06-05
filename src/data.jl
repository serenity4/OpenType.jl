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
    gsub::Optional{GlyphSubstitutionTable}
    gpos::Optional{GlyphPositioningTable}
    gdef::Optional{GlyphDefinitionTable}
end

Base.broadcastable(data::OpenTypeData) = Ref(data)

"""
Read OpenType font data from `io`.

A specification for OpenType font files is available
at https://docs.microsoft.com/en-us/typography/opentype/spec/otff
"""

BinaryParsingTools.swap_endianness(io::IO, ::Type{OpenTypeData}) = peek(io, UInt32) == 0x00000100

function Base.read(io::Union{BinaryIO, TracedIO{<:BinaryIO}}, ::Type{OpenTypeData}; verify_checksums::Bool = true)
    table_directory, nav = TableNavigationMap(io)
    if verify_checksums
        ret = @__MODULE__().verify_checksums(io, nav)
        if isa(ret, InvalidFontException)
            if startswith(ret.msg, "Invalid font checksum")
                # The master checksum can be allowed to fail.
                @warn ret.msg
            else
                # Table checksums should really not fail.
                throw(ret)
            end
        end
    end
    read(io, OpenTypeData, table_directory, nav)
end

function TableNavigationMap(io::IO)
    sfnt = peek(io, UInt32)
    sfnt in (0x00010000, 0x4F54544F) || error_invalid_font("Invalid format: unknown SFNT version (expected 0x00010000 or 0x4F54544F). The provided IO may not describe an OpenType font, or may describe one that is not conform to the OpenType specification.")
    table_directory = read(io, TableDirectory)
    nav = TableNavigationMap(table_directory.table_records)
    @debug "Available tables: $(join(getproperty.(values(nav.map), :tag), ", "))"
    table_directory, nav
end

function Base.read(io::IO, ::Type{OpenTypeData}, table_directory::TableDirectory, nav::TableNavigationMap)
    cmap = read_table(Base.Fix2(read, CharacterToGlyphIndexMappingTable), io, nav, tag"cmap")::CharacterToGlyphIndexMappingTable
    head = read_table(Base.Fix2(read, FontHeader), io, nav, tag"head")::FontHeader
    hhea = read_table(Base.Fix2(read, HorizontalHeader), io, nav, tag"hhea")::HorizontalHeader
    maxp = read_table(Base.Fix2(read, MaximumProfile), io, nav, tag"maxp")::MaximumProfile
    hmtx = read_table(io -> read(io, HorizontalMetrics, hhea, maxp), io, nav, tag"hmtx")::HorizontalMetrics

    # TrueType outlines.
    loca = read_table(io -> read(io, IndexToLocation, maxp, head), io, nav, tag"loca")
    glyf = read_table(io -> read(io, GlyphTable, head, maxp, nav, loca), io, nav, tag"glyf")
    vhea = read_table(Base.Fix2(read, VerticalHeader), io, nav, tag"vhea")
    vmtx = read_table(io -> read(io, VerticalMetrics, vhea, maxp), io, nav, tag"vmtx")

    # Font variations.
    avar = read_table(Base.Fix2(read, AxisVariationsTable), io, nav, tag"avar")
    fvar = read_table(Base.Fix2(read, FontVariationsTable), io, nav, tag"fvar")

    # Advanced typographic tables.
    gsub = read_table(Base.Fix2(read, GlyphSubstitutionTable), io, nav, tag"GSUB")
    gpos = read_table(Base.Fix2(read, GlyphPositioningTable), io, nav, tag"GPOS")
    gdef = read_table(Base.Fix2(read, GlyphDefinitionTable), io, nav, tag"GDEF")

    OpenTypeData(table_directory, cmap, head, hhea, hmtx, maxp, nothing, nothing, nothing, vhea, vmtx, loca, glyf, avar, fvar, gsub, gpos, gdef)
end

function OpenTypeData(file::AbstractString; verify_checksums::Bool = true, debug::Bool = false)
    open(file) do io
        if !debug
            read_binary(io, OpenTypeData; verify_checksums)
        else
            io = BinaryParsingTools.BinaryIO(BinaryParsingTools.swap_endianness(io, OpenTypeData), io)
            io = TracedIO(io)
            table_directory, nav = TableNavigationMap(io)
            read(io, OpenTypeData)

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

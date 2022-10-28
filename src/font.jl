"""
Structured representation of an OpenType font.
"""
struct OpenTypeFont
    # Font metadata.
    created::DateTime
    modified::DateTime
    last_resort_font::Bool
    units_per_em::UInt16

    cmap_subtable_index::Int
    glyphs::Vector{Union{Nothing,SimpleGlyph,CompositeGlyph}}
    gpos::GlyphPositioning

    # Old tables, simply passed along for now (waiting for an abstraction to be defined).
    cmap::CharacterToGlyphIndexMappingTable
    hmtx::Optional{HorizontalMetrics}
    vmtx::Optional{VerticalMetrics}
    gdef::Optional{GlyphDefinitionTable}
end

Base.broadcastable(font::OpenTypeFont) = Ref(font)

datetime(long::LONGDATETIME) = DateTime(1904, 1, 1) + Second(long)

function OpenTypeFont(data::OpenTypeData)
    @assert !isnothing(data.glyf)
    @assert !isnothing(data.loca)
    glyphs = read_glyphs(data)
    cmap_subtable_index = pick_table_index(data.cmap.subtables)
    isnothing(cmap_subtable_index) && error("No supported subtable for the character to glyph mapping was found. Supported formats are 12, 10, 4, 6 and 0.")
    !isnothing(data.gpos) || error("Only fonts with GPOS tables are supported.")
    (; head) = data
    OpenTypeFont(datetime(head.created), datetime(head.modified), in(FONT_LAST_RESORT, head.flags), head.units_per_em, cmap_subtable_index, glyphs, GlyphPositioning(data.gpos), data.cmap, data.hmtx, data.vmtx, data.gdef)
end

Base.getindex(font::OpenTypeFont, char::Char) = font[glyph_index(font, char)]
Base.getindex(font::OpenTypeFont, id::GlyphID) = font.glyphs[1 + id]

OpenTypeFont(file::AbstractString) = OpenTypeFont(OpenTypeData(file))

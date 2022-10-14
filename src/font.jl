"""
Structured representation of an OpenType font.
"""
struct OpenTypeFont
    # Font metadata.
    created::DateTime
    modified::DateTime
    last_resort_font::Bool
    units_per_em::UInt16

    cmap::CharacterToGlyphIndexMappingTable
    cmap_subtable_index::Int
    glyphs::Vector{Union{Nothing,SimpleGlyph,CompositeGlyph}}
    gpos::GlyphPositioning
end

datetime(long::LONGDATETIME) = DateTime(1904, 1, 1) + Second(long)

function OpenTypeFont(data::OpenTypeData)
    @assert !isnothing(data.glyf)
    @assert !isnothing(data.loca)
    glyphs = read_glyphs(data)
    cmap_subtable_index = pick_table_index(data.cmap.subtables)
    isnothing(cmap_subtable_index) && error("No supported subtable for the character to glyph mapping was found. Supported formats are 12, 10, 4, 6 and 0.")
    !isnothing(data.gpos) || error("Only fonts with GPOS tables are supported.")
    (; head) = data
    OpenTypeFont(datetime(head.created), datetime(head.modified), in(FONT_LAST_RESORT, head.flags), head.units_per_em, data.cmap, cmap_subtable_index, glyphs, GlyphPositioning(data.gpos))
end

Base.getindex(font::OpenTypeFont, char::Char) = font.glyphs[1 + glyph_index(font, char)]

OpenTypeFont(file::AbstractString) = OpenTypeFont(OpenTypeData(file))

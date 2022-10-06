"""
Structured representation of an OpenType font.
"""
struct OpenTypeFont
    cmap::CharacterToGlyphIndexMappingTable
    cmap_subtable_index::Int
    glyphs::Vector{Union{SimpleGlyph,CompositeGlyph}}
end

function OpenTypeFont(data::OpenTypeData)
    @assert !isnothing(data.glyf)
    @assert !isnothing(data.loca)
    glyphs = read_glyphs(data)
    cmap_subtable_index = pick_table_index(data.cmap.subtables)
    isnothing(cmap_subtable_index) && error("No supported subtable for the character to glyph mapping was found. Supported formats are 12, 10, 4, 6 and 0.")
    OpenTypeFont(data.cmap, cmap_subtable_index, glyphs)
end

Base.getindex(font::OpenTypeFont, char::Char) = font.glyphs[glyph_index(font, char)]

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
    gsub::Optional{GlyphSubstitution}
    gpos::Optional{GlyphPositioning}
    gdef::Optional{GlyphDefinition}

    # Old tables, simply passed along for now (waiting for an abstraction to be defined).
    cmap::CharacterToGlyphIndexMappingTable
    hmtx::Optional{HorizontalMetrics}
    vmtx::Optional{VerticalMetrics}
    hhea::Optional{HorizontalHeader}
    vhea::Optional{VerticalHeader}
end

Base.broadcastable(font::OpenTypeFont) = Ref(font)

datetime(long::LONGDATETIME) = DateTime(1904, 1, 1) + Second(long)

function OpenTypeFont(data::OpenTypeData)
    @assert !isnothing(data.glyf)
    @assert !isnothing(data.loca)
    glyphs = read_glyphs(data)
    cmap_subtable_index = pick_table_index(data.cmap.subtables)
    isnothing(cmap_subtable_index) && error("No supported subtable for the character to glyph mapping was found. Supported formats are 12, 10, 4, 6 and 0.")
    (; head) = data
    gsub = isnothing(data.gsub) ? nothing : GlyphSubstitution(data.gsub)
    gpos = isnothing(data.gpos) ? nothing : GlyphPositioning(data.gpos)
    gdef = isnothing(data.gdef) ? nothing : GlyphDefinition(data.gdef)
    OpenTypeFont(datetime(head.created), datetime(head.modified), in(FONT_LAST_RESORT, head.flags), head.units_per_em, cmap_subtable_index, glyphs, gsub, gpos, gdef, data.cmap, data.hmtx, data.vmtx, data.hhea, data.vhea)
end

Base.getindex(font::OpenTypeFont, char::Char) = font[glyph_index(font, char)]
Base.getindex(font::OpenTypeFont, id::GlyphID) = font.glyphs[1 + id]

OpenTypeFont(file::AbstractString) = OpenTypeFont(OpenTypeData(file))

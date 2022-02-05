struct OpenTypeFont
    glyphs::Vector{Union{SimpleGlyph,CompositeGlyph}}
end

function OpenTypeFont(data::OpenTypeData)
    @assert !isnothing(data.glyf)
    @assert !isnothing(data.loca)
    glyphs = read_glyphs(data)
    OpenTypeFont(glyphs)
end

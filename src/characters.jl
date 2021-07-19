function Glyph(font::OpenTypeFont, char::Char; pick_table=first)
    tables = values(font.cmap.tables)
    table = pick_table(tables)
    if table isa ByteEncodingTable
        offset = table.glyph_id_array[UInt8(char)]
    elseif table isa SegmentedCoverage
        offset = 0
        char_uint = UInt32(char)
        for group in table.groups
            if char_uint in group.char_range
                offset = group.start_glyph_id + (char_uint - group.char_range.start)
                break
            end
        end
    else
        error("Unsupported table type $(typeof(table))")
    end
    font.glyphs[1 + offset]
end

Base.getindex(font::OpenTypeFont, char::Char) = Glyph(font, char)

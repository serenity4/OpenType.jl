function pick_table_index(subtables)
    format(t) = t.format
    i = findfirst(==(12) ∘ format, subtables)
    isnothing(i) && (i = findfirst(==(10) ∘ format, subtables))
    isnothing(i) && (i = findfirst(==(4) ∘ format, subtables))
    isnothing(i) && (i = findfirst(==(6) ∘ format, subtables))
    isnothing(i) && (i = findfirst(==(0) ∘ format, subtables))
    i
end

"""
Get the glyph index corresponding to the character `char`.
"""
function glyph_index(font::OpenTypeFont, char::Char)
    table = font.cmap.subtables[font.cmap_subtable_index]
    if table isa ByteEncodingTable
        return table.glyph_id_array[UInt8(char)] + 1
    elseif table isa SegmentedCoverage
        char_uint = UInt32(char)
        for group in table.groups
            range = group.start_char_code:group.end_char_chode
            if char_uint in range
                return group.start_glyph_id + (char_uint - range.start) + 1
            end
        end
        return 0
    else
        error("Unsupported table type $(typeof(table))")
    end
end

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
        return table.glyph_id_array[UInt8(char)]
    elseif table isa SegmentedCoverage
        char_uint = UInt32(char)
        for group in table.groups
            range = group.start_char_code:group.end_char_chode
            if char_uint in range
                return group.start_glyph_id + (char_uint - range.start)
            end
        end
        return 0
    elseif table isa SegmentMappingToDeltaValues
        char_uint = UInt32(char)
        segment_id = findfirst(≥(char_uint), table.end_code)
        # The last end code should be 0xffff, but we never know.
        # Better not to error if that's not the case.
        isnothing(segment_id) && return 0
        start = table.start_code[segment_id]
        if start > char_uint
            # The character code ended up between two segments.
            return 0
        end
        range_offset = table.id_range_offsets[segment_id]
        delta = table.id_delta[segment_id]
        iszero(range_offset) && return char_uint + delta
        char_offset = char_uint - start
        # See https://stackoverflow.com/questions/57461636/how-to-correctly-understand-truetype-cmaps-subtable-format-4
        # to get this expression from the pointer arithmetic described in the specification.
        glyph_id = table.glyph_id_array[segment_id - end + Int(range_offset / 2) + char_offset]
        iszero(glyph_id) && return glyph_id
        return delta + glyph_id
    else
        error("Unsupported table type $(typeof(table))")
    end
end

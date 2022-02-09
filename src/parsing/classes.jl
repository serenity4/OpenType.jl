abstract type ClassDefinitionTable end

@serializable struct ClassDefinitionTableFormat1 <: ClassDefinitionTable
    class_format::UInt16
    start_glyph_id::UInt16
    glyph_count::UInt16
    class_value_array::Vector{UInt16} => glyph_count
end

@serializable struct ClassRangeRecord
    start_glyph_id::UInt16
    end_glyph_id::UInt16
    class::UInt16
end

@serializable struct ClassDefinitionTableFormat2 <: ClassDefinitionTable
    class_format::UInt16
    class_range_count::UInt16
    class_range_records::Vector{ClassRangeRecord} => class_range_count
end

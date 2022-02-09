abstract type CoverageTable end

@serializable struct CoverageTableFormat1 <: CoverageTable
    coverage_format::UInt16
    glyph_count::UInt16
    glyph_array::Vector{UInt16} => glyph_count
end

@serializable struct RangeRecord
    start_glyph_id::UInt16
    end_glyph_id::UInt16
    start_coverage_index::UInt16
end

@serializable struct CoverageTableFormat2 <: CoverageTable
    coverage_format::UInt16
    range_count::UInt16
    range_records::Vector{RangeRecord} => range_count
end

function Base.read(io::IO, ::Type{CoverageTable})
    coverage_format = peek(io, UInt16)
    coverage_format == 1 ? read(io, CoverageTableFormat1) : read(io, CoverageTableFormat2)
end

@serializable struct SequenceLookupRecord
    sequence_index::UInt16
    lookup_list_index::UInt16
end

@serializable struct SequenceRuleTable
    glyph_count::UInt16
    seq_lookup_count::UInt16
    input_sequence::Vector{UInt16} => glyph_count - 1
    seq_lookup_records::Vector{SequenceLookupRecord} => seq_lookup_count
end

@serializable struct SequenceRuleSetTable
    seq_rule_count::UInt16
    seq_rule_offsets::Vector{UInt16} => seq_rule_count

    seq_rule_tables::Vector{SequenceRuleTable} << [read_at(io, SequenceRuleTable, offset; start = __origin__) for offset in seq_rule_offsets]
end

"""
Table used for matching against particular sequence contexts.

There are different context types: chained contexts, and simple contexts. A simple context is a pattern defined by a list of glyphs; a chained context is a simple context with a lookbehind and a lookahead context, wherein actions only apply to the inner context.

Matching against glyphs may be encoded for individual glyphs, classes of glyphs, or ranges of glyphs.

Pattern matching is activated if a glyph is encountered that is part of any pattern matching. A coverage table indicates the set of activating glyphs.
The coverage table outputs an index that is then used to access the different pattern data structures. Note that all indices are 0-based.
"""
abstract type SequenceContextTable end

@serializable struct SequenceContextTableFormat1 <: SequenceContextTable
    format::UInt16
    coverage_offset::UInt16
    seq_rule_set_count::UInt16
    seq_rule_set_offsets::Vector{UInt16} => seq_rule_set_count

    coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
    seq_rule_set_tables::Vector{Optional{SequenceRuleSetTable}} << [iszero(offset) ? nothing : read_at(io, SequenceRuleSetTable, offset; start = __origin__) for offset in seq_rule_set_offsets]
end

@serializable struct SequenceContextTableFormat2 <: SequenceContextTable
    format::UInt16
    coverage_offset::UInt16
    class_def_offset::UInt16
    class_seq_rule_set_count::UInt16
    class_seq_rule_set_offsets::Vector{UInt16} => class_seq_rule_set_count

    coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
    class_def_table::ClassDefinitionTable << read_at(io, ClassDefinitionTable, class_def_offset; start = __origin__)
    class_seq_rule_set_tables::Vector{Optional{SequenceRuleSetTable}} << [iszero(offset) ? nothing : read_at(io, SequenceRuleSetTable, offset; start = __origin__) for offset in class_seq_rule_set_offsets]
end

@serializable struct SequenceContextTableFormat3 <: SequenceContextTable
    format::UInt16
    glyph_count::UInt16
    seq_lookup_count::UInt16
    coverage_offsets::Vector{UInt16} => glyph_count
    seq_lookup_records::Vector{SequenceLookupRecord} => seq_lookup_count

    coverage_tables::Vector{CoverageTable} << [read_at(io, CoverageTable, offset; start = __origin__) for offset in coverage_offsets]
end

function Base.read(io::IO, ::Type{SequenceContextTable})
    format = peek(io, UInt16)
    format == 1 && return read(io, SequenceContextTableFormat1)
    format == 2 && return read(io, SequenceContextTableFormat2)
    format == 3 && return read(io, SequenceContextTableFormat3)
    @assert false
end

@serializable struct ChainedSequenceRuleTable
    backtrack_glyph_count::UInt16
    backtrack_sequence::Vector{UInt16} => backtrack_glyph_count
    input_glyph_count::UInt16
    input_sequence::Vector{UInt16} => input_glyph_count - 1
    lookahead_glyph_count::UInt16
    lookahead_sequence::Vector{UInt16} => lookahead_glyph_count
    seq_lookup_count::UInt16
    seq_lookup_records::Vector{SequenceLookupRecord} => seq_lookup_count
end

@serializable struct ChainedSequenceRuleSetTable
    chained_seq_rule_count::UInt16
    chained_seq_rule_offsets::Vector{UInt16} => chained_seq_rule_count

    chained_seq_rule_tables::Vector{ChainedSequenceRuleTable} << [read_at(io, ChainedSequenceRuleTable, offset; start = __origin__) for offset in chained_seq_rule_offsets]
end

abstract type ChainedSequenceContextTable end

@serializable struct ChainedSequenceContextFormat1 <: ChainedSequenceContextTable
    format::UInt16
    coverage_offset::UInt16
    chained_seq_rule_set_count::UInt16
    chained_seq_rule_set_offsets::Vector{UInt16} => chained_seq_rule_set_count

    coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
    chained_seq_rule_set_tables::Vector{ChainedSequenceRuleSetTable} << [read_at(io, ChainedSequenceRuleSetTable, offset; start = __origin__) for offset in chained_seq_rule_set_offsets]
end

@serializable struct ChainedSequenceContextFormat2 <: ChainedSequenceContextTable
    format::UInt16
    coverage_offset::UInt16
    backtrack_class_def_offset::UInt16
    input_class_def_offset::UInt16
    lookahead_class_def_offset::UInt16
    chained_class_seq_rule_set_count::UInt16
    chained_class_seq_rule_set_offsets::Vector{UInt16} => chained_class_seq_rule_set_count

    coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
    backtrack_class_def_table::ClassDefinitionTable << read_at(io, ClassDefinitionTable, backtrack_class_def_offset; start = __origin__)
    input_class_def_table::ClassDefinitionTable << read_at(io, ClassDefinitionTable, input_class_def_offset; start = __origin__)
    lookahead_class_def_table::ClassDefinitionTable << read_at(io, ClassDefinitionTable, lookahead_class_def_offset; start = __origin__)
    # To be exact, the element type is `ChainedClassSequenceRuleSetTable`, but this type is structurally identical to `ChainedSequenceRuleSetTable`.
    chained_class_seq_rule_set_tables::Vector{ChainedSequenceRuleSetTable} << [read_at(io, ChainedSequenceRuleSetTable, offset; start = __origin__) for offset in chained_class_seq_rule_set_offsets]
end

@serializable struct ChainedSequenceContextFormat3 <: ChainedSequenceContextTable
    format::UInt16
    backtrack_glyph_count::UInt16
    backtrack_coverage_offsets::Vector{UInt16} => backtrack_glyph_count
    input_glyph_count::UInt16
    input_coverage_offsets::Vector{UInt16} => input_glyph_count
    lookahead_glyph_count::UInt16
    lookahead_coverage_offsets::Vector{UInt16} => lookahead_glyph_count
    seq_lookup_count::UInt16
    seq_lookup_records::Vector{SequenceLookupRecord} => seq_lookup_count

    backtrack_coverage_tables::Vector{CoverageTable} << [read_at(io, CoverageTable, offset; start = __origin__) for offset in backtrack_coverage_offsets]
    input_coverage_tables::Vector{CoverageTable} << [read_at(io, CoverageTable, offset; start = __origin__) for offset in input_coverage_offsets]
    lookahead_coverage_tables::Vector{CoverageTable} << [read_at(io, CoverageTable, offset; start = __origin__) for offset in lookahead_coverage_offsets]
end

function Base.read(io::IO, ::Type{ChainedSequenceContextTable})
    format = peek(io, UInt16)
    format == 1 && return read(io, ChainedSequenceContextFormat1)
    format == 2 && return read(io, ChainedSequenceContextFormat2)
    format == 3 && return read(io, ChainedSequenceContextFormat3)
    @assert false
end

@enum GSUBLookupType::UInt8 begin
    GSUB_LOOKUP_SINGLE = 0x01
    GSUB_LOOKUP_MULTIPLE = 0x02
    GSUB_LOOKUP_ALTERNATE = 0x03
    GSUB_LOOKUP_LIGATURE = 0x04
    GSUB_LOOKUP_CONTEXT = 0x05
    GSUB_LOOKUP_CHAINING_CONTEXT = 0x06
    GSUB_LOOKUP_EXTENSION_SUBSTITUTION = 0x07
    GSUB_LOOKUP_REVERSE_CHAINING_CONTEXT_SINGLE = 0x08
end

@serializable struct GSUBHeader
    major_version::UInt16
    minor_version::UInt16
    script_list_offset::UInt16
    feature_list_offset::UInt16
    lookup_list_offset::UInt16
end

abstract type GSUBLookupSubtable{N} end

abstract type GSUBLookupSingleTable <: GSUBLookupSubtable{1} end

@serializable struct SingleTableFormat1 <: GSUBLookupSingleTable
    subst_format::UInt16
    coverage_offset::UInt16
    delta_glyph_id::GlyphIDOffset

    coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
end

@serializable struct SingleTableFormat2 <: GSUBLookupSingleTable
    subst_format::UInt16
    coverage_offset::UInt16
    glyph_count::UInt16
    substitute_glyph_ids::Vector{GlyphID} => glyph_count

    coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
end

function Base.read(io::IO, ::Type{GSUBLookupSubtable{1}})
    subst_format = peek(io, UInt16)
    subst_format == 1 ? read(io, SingleTableFormat1) : read(io, SingleTableFormat2)
end

@serializable struct SequenceTable
  glyph_count::UInt16
  substitute_glyph_ids::Vector{GlyphID} => glyph_count
end

@serializable struct GSUBLookupMultipleTable <: GSUBLookupSubtable{2}
  subst_format::UInt16
  coverage_offset::UInt16
  sequence_count::UInt16
  sequence_offsets::Vector{UInt16} => sequence_count

  sequence_tables::Vector{SequenceTable} << [read_at(io, SequenceTable, offset; start = __origin__) for offset in sequence_offsets]
  coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
end

Base.read(io::IO, ::Type{GSUBLookupSubtable{2}}) = read(io, GSUBLookupMultipleTable)

@serializable struct AlternateSetTable
  glyph_count::UInt16
  alternate_glyph_ids::Vector{GlyphID} => glyph_count
end

@serializable struct GSUBLookupAlternateTable <: GSUBLookupSubtable{3}
    subst_format::UInt16
    coverage_offset::UInt16
    alternate_set_count::UInt16
    alternate_set_offsets::Vector{UInt16} => alternate_set_count

    alternate_set_tables::Vector{AlternateSetTable} << [read_at(io, AlternateSetTable, offset; start = __origin__) for offset in alternate_set_offsets]
    coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
end

Base.read(io::IO, ::Type{GSUBLookupSubtable{3}}) = read(io, GSUBLookupAlternateTable)

@serializable struct LigatureTable
  ligature_glyph::GlyphID
  component_count::UInt16
  component_glyph_ids::Vector{GlyphID} => component_count
end

@serializable struct LigatureSetTable
  ligature_count::UInt16
  ligature_offsets::Vector{UInt16} => ligature_count

  ligature_tables::Vector{LigatureTable} <<  [read_at(io, LigatureTable, offset; start = __origin__) for offset in ligature_offsets]
end

@serializable struct GSUBLookupLigatureTable <: GSUBLookupSubtable{4}
  subst_format::UInt16
  coverage_offset::UInt16
  ligature_set_counts::UInt16
  ligature_set_offsets::Vector{UInt16} => ligature_set_counts

  ligature_set_tables::Vector{LigatureSetTable} << [read_at(io, LigatureSetTable, offset; start = __origin__) for offset in ligature_set_offsets]
  coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
end

Base.read(io::IO, ::Type{GSUBLookupSubtable{4}}) = read(io, GSUBLookupLigatureTable)

@serializable struct GSUBContextualTable <: GSUBLookupSubtable{5}
    table::SequenceContextTable
end

Base.read(io::IO, ::Type{GSUBLookupSubtable{5}}) = read(io, GSUBContextualTable)

@serializable struct GSUBChainedContextualTable <: GSUBLookupSubtable{6}
    table::ChainedSequenceContextTable
end

Base.read(io::IO, ::Type{GSUBLookupSubtable{6}}) = read(io, GSUBChainedContextualTable)

@serializable struct GSUBLookupTable <: LookupTable
    lookup_type::UInt16
    lookup_flag::LookupFlag
    subtable_count::UInt16
    subtable_offsets::Vector{UInt16} => subtable_count
    mark_filtering_set::Optional{UInt16} << (in(LOOKUP_USE_MARK_FILTERING_SET, lookup_flag) ? read(io, UInt16) : nothing)

    subtables::Vector{GSUBLookupSubtable} << [read_at(io, GSUBLookupSubtable{Int(lookup_type)}, offset; start = __origin__) for offset in subtable_offsets]
end

@serializable struct GSUBExtensionTable <: GSUBLookupSubtable{7}
    pos_format::UInt16
    extension_lookup_type::UInt16
    extension_offset::UInt32

    extension_table::GSUBLookupSubtable << read_at(io, GSUBLookupSubtable{Int(extension_lookup_type)}, extension_offset; start = __origin__)
end

Base.read(io::IO, ::Type{GSUBLookupSubtable{7}}) = read(io, GSUBExtensionTable)

@serializable struct GlyphSubstitutionTable
    header::GSUBHeader
    script_list_table::ScriptListTable << read_at(io, ScriptListTable, header.script_list_offset; start = __origin__)
    feature_list_table::FeatureListTable << read_at(io, FeatureListTable, header.feature_list_offset; start = __origin__)
    lookup_list_table::LookupListTable << read_at(io, LookupListTable, header.lookup_list_offset, GSUBLookupTable; start = __origin__)
end

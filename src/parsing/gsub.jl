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
    delta_glyph_id::GlyphOffset
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
  subtitute_glyph_ids::Vector{GlyphID} => glyph_count
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
    alternate_set_offsets::Vector{AlternateSetTable} => alternate_set_count
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

#=

@serializable struct MarkRecord
    mark_class::UInt16
    mark_anchor_offset::UInt16
    mark_anchor_table::AnchorTable
end

@serializable struct MarkArrayTable
    mark_count::UInt16
    mark_records::Vector{MarkRecord} => mark_count
end

struct BaseArrayTable
    base_count::UInt16
    base_records::Vector{Vector{UInt16}}
end

function Base.read(io::IO, ::Type{BaseArrayTable}, mark_class_count)
    base_count = read(io, UInt16)
    BaseArrayTable(base_count, [[read(io, UInt16) for _ in 1:mark_class_count] for _ in 1:base_count])
end

@serializable struct GSUBLookupMarkToBaseAttachmentTable <: GSUBLookupSubtable{4}
    subst_format::UInt16
    mark_coverage_offset::UInt16
    base_coverage_offset::UInt16
    mark_class_count::UInt16
    mark_array_offset::UInt16
    base_array_offset::UInt16
    mark_coverage_table::CoverageTable << read_at(io, CoverageTable, mark_coverage_offset; start = __origin__)
    base_coverage_table::CoverageTable << read_at(io, CoverageTable, base_coverage_offset; start = __origin__)
    mark_array_table::MarkArrayTable << read_at(io, MarkArrayTable, mark_array_offset; start = __origin__)
    base_array_table::BaseArrayTable << read_at(io, BaseArrayTable, base_array_offset, mark_class_count; start = __origin__)
end

Base.read(io::IO, ::Type{GSUBLookupSubtable{4}}) = read(io, GSUBLookupMarkToBaseAttachmentTable)

struct LigatureAttachTable
    component_count::UInt16
    component_records::Vector{Vector{UInt16}}
end

function Base.read(io::IO, ::Type{LigatureAttachTable}, mark_class_count)
    component_count = read(io, UInt16)
    LigatureAttachTable(component_count, [[read(io, UInt16) for _ in 1:mark_class_count] for _ in 1:component_count])
end

struct LigatureArrayTable
    ligature_count::UInt16
    ligature_attach_offsets::Vector{UInt16}
    ligature_attach_table::Vector{LigatureAttachTable}
end

function Base.read(io::IO, ::Type{LigatureArrayTable}, mark_class_count)
    ligature_count = read(io, UInt16)
    ligature_attach_offsets = [read(io, UInt16) for _ in 1:ligature_count]
    ligature_attach_table = read(io, LigatureAttachTable, mark_class_count)
    LigatureArrayTable(ligature_count, ligature_attach_offsets, ligature_attach_table)
end

@serializable struct GSUBLookupMarkToLigatureAttachmentTable <: GSUBLookupSubtable{5}
    subst_format::UInt16
    mark_coverage_offset::UInt16
    ligature_coverage_offset::UInt16
    mark_class_count::UInt16
    mark_array_offset::UInt16
    ligature_array_offset::UInt16
    mark_coverage_table::CoverageTable << read_at(io, CoverageTable, mark_coverage_offset; start = __origin__)
    ligature_coverage_table::CoverageTable << read_at(io, CoverageTable, ligature_coverage_offset; start = __origin__)
    mark_array_table::MarkArrayTable << read_at(io, MarkArrayTable, mark_array_offset; start = __origin__)
    ligature_array_table::LigatureArrayTable << read_at(io, LigatureArrayTable, ligature_array_offset, mark_class_count; start = __origin__)
end

Base.read(io::IO, ::Type{GSUBLookupSubtable{5}}) = read(io, GSUBLookupMarkToLigatureAttachmentTable)

struct Mark2Record
    mark_2_anchor_offsets::Vector{UInt16}
end

Base.read(io::IO, ::Type{Mark2Record}, mark_class_count) = Mark2Record([read(io, UInt16) for _ in 1:mark_class_count])

struct Mark2ArrayTable
    mark_count::UInt16
    mark_records::Vector{Mark2Record}
end

function Base.read(io::IO, ::Type{Mark2ArrayTable}, mark_class_count)
    mark_count = read(io, UInt16)
    Mark2ArrayTable(mark_count, [read(io, Mark2Record, mark_class_count) for _ in 1:mark_count])
end

@serializable struct GSUBLookupMarkToMarkAttachmentTable <: GSUBLookupSubtable{6}
    subst_format::UInt16
    mark_1_coverage_offset::UInt16
    mark_2_coverage_offset::UInt16
    mark_class_count::UInt16
    mark_1_array_offset::UInt16
    mark_2_array_offset::UInt16
    mark_1_coverage_table::CoverageTable << read_at(io, CoverageTable, mark_1_coverage_offset; start = __origin__)
    mark_2_coverage_table::CoverageTable << read_at(io, CoverageTable, mark_2_coverage_offset; start = __origin__)
    mark_1_array_table::Mark2ArrayTable << read_at(io, Mark2ArrayTable, mark_array_offset, mark_class_count; start = __origin__)
    mark_2_array_table::Mark2ArrayTable << read_at(io, Mark2ArrayTable, mark_array_offset, mark_class_count; start = __origin__)
end

Base.read(io::IO, ::Type{GSUBLookupSubtable{6}}) = read(io, GSUBLookupMarkToMarkAttachmentTable)

@serializable struct GSUBContextualTable <: GSUBLookupSubtable{7}
    table::SequenceContextTable
end

Base.read(io::IO, ::Type{GSUBLookupSubtable{7}}) = read(io, GSUBContextualTable)

#TODO: Implement format 8.
# @serializable struct GSUBChainedContextualTable <: GSUBLookupSubtable{8}
#     table::ChainedSequenceContextTable
# end

Base.read(io::IO, ::Type{GSUBLookupSubtable{8}}) = read(io, GSUBChainedContextualTable)

@serializable struct GSUBLookupTable <: LookupTable
    lookup_type::UInt16
    lookup_flag::UInt16
    subtable_count::UInt16
    subtable_offsets::Vector{UInt16} => subtable_count
    mark_filtering_set::UInt16
    subtables::Vector{GSUBLookupSubtable} << [read_at(io, GSUBLookupSubtable, offset; start = __origin__) for offset in subtable_offsets]
end

=#

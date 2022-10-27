@enum GlyphClassDef::UInt16 begin
    GLYPH_CLASS_BASE = 1
    GLYPH_CLASS_LIGATURE = 2
    GLYPH_CLASS_MARK = 3
    GLYPH_CLASS_COMPONENT = 4
end

@serializable struct AttachPointTable
  point_count::UInt16
  point_indices::Vector{UInt16} => point_count
end

@serializable struct AttachmentPointListTable
  coverage_offset::UInt16
  glyph_count::UInt16
  attach_point_offsets::Vector{UInt16} => glyph_count

  coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
  attach_point_tables::Vector{AttachPointTable} << [read_at(io, AttachPointTable, offset; start = __origin__) for offset in attach_point_offsets]
end

abstract type CaretValueTable end

@serializable struct CaretValueTableFormat1 <: CaretValueTable
  caret_value_format::UInt16
  coordinate::Int16
end

@serializable struct CaretValueTableFormat2 <: CaretValueTable
  caret_value_format::UInt16
  caret_value_point_index::UInt16
end

@serializable struct CaretValueTableFormat3 <: CaretValueTable
  caret_value_format::UInt16
  coordinate::Int16
  device_offset::UInt16

  device_table::Union{DeviceTable,VariationIndexTable} << read_at(io, Union{DeviceTable,VariationIndexTable}, device_offset; start = __origin__)
end

function Base.read(io::IO, ::Type{CaretValueTable})
  format = peek(io, UInt16)
  format == 1 && return read(io, CaretValueTableFormat1)
  format == 2 && return read(io, CaretValueTableFormat2)
  read(io, CaretValueTableFormat3)
end

@serializable struct LigatureGlyphTable
  caret_count::UInt16
  caret_value_offsets::Vector{UInt16} => caret_count

  caret_value_tables::Vector{CaretValueTable} << [read_at(io, CaretValueTable, offset; start = __origin__) for offset in caret_value_offsets]
end

@serializable struct LigatureCaretListTable
  coverage_offset::UInt16
  lig_glyph_count::UInt16
  lig_glyph_offsets::Vector{UInt16} => lig_glyph_count

  coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
  lig_glyph_tables::Vector{LigatureGlyphTable} << [read_at(io, LigatureGlyphTable, offset; start = __origin__) for offset in attach_point_offsets]
end

@serializable struct GDEFHeader_1_0
  major_version::UInt16
  minor_version::UInt16
  glyph_class_def_offset::UInt16
  attach_list_offset::UInt16
  lig_caret_list_offset::UInt16
  mark_attach_class_def_offset::UInt16

  glyph_class_def_table::ClassDefinitionTable << read_at(io, ClassDefinitionTable, glyph_class_def_offset; start = __origin__)
  attach_list_table::AttachmentPointListTable << read_at(io, AttachmentPointListTable, attach_list_offset; start = __origin__)
  lig_caret_list_table::LigatureCaretListTable << read_at(io, LigatureCaretListTable, lig_caret_list_offset ; start = __origin__)
  mark_attach_class_def_table::ClassDefinitionTable << read_at(io, ClassDefinitionTable, mark_attach_class_def_offset; start = __origin__)
end

@serializable struct MarkGlyphSetsTable
  format::UInt16
  mark_glyph_set_count::UInt16
  coverage_offsets::Vector{UInt32} => mark_glyph_set_count

  coverage_tables::Vector{CoverageTable} << [read_at(io, CoverageTable, offset; start = __origin__) for offset in coverage_offsets]
end

@serializable struct GDEFHeader_1_2
  common::GDEFHeader_1_0
  mark_glyph_sets_def_offset::UInt16

  mark_glyph_sets_def_table::MarkGlyphSetsTable << read_at(io, MarkGlyphSetsTable, mark_glyph_sets_def_offset; start = __origin__)
end

@serializable struct GDEFHeader_1_3
  common::GDEFHeader_1_3
  item_var_store_offset::UInt16

  item_var_store_table::Any # TODO
end

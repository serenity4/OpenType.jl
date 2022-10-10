@enum GPOSLookupType::UInt8 begin
    GPOS_LOOKUP_SINGLE_ADJUSTMENT = 0x01
    GPOS_LOOKUP_PAIR_ADJUSTMENT = 0x02
    GPOS_LOOKUP_CURSIVE_ATTACHMENT = 0x03
    GPOS_LOOKUP_MARK_TO_BASE_ATTACHMENT = 0x04
    GPOS_LOOKUP_MARK_TO_LIGATURE_ATTACHMENT = 0x05
    GPOS_LOOKUP_MARK_TO_MARK_ATTACHMENT = 0x06
    GPOS_LOOKUP_CONTEXT_POSITIONING = 0x07
    GPOS_LOOKUP_CHAINED_CONTEXT_POSITIONING = 0x08
    GPOS_LOOKUP_EXTENSION_POSITIONING = 0x09
end

@serializable struct GPOSHeader
    major_version::UInt16
    minor_version::UInt16
    script_list_offset::UInt16
    feature_list_offset::UInt16
    lookup_list_offset::UInt16
    feature_variations_offset::Optional{UInt32} << (minor_version == 1 ? read(io, UInt32) : nothing)
end

@bitmask ValueFormat::UInt16 begin
    VALUE_FORMAT_X_PLACEMENT = 0x0001
    VALUE_FORMAT_Y_PLACEMENT = 0x0002
    VALUE_FORMAT_X_ADVANCE = 0x0004
    VALUE_FORMAT_Y_ADVANCE = 0x0008
    VALUE_FORMAT_X_PLACEMENT_DEVICE = 0x0010
    VALUE_FORMAT_Y_PLACEMENT_DEVICE = 0x0020
    VALUE_FORMAT_X_ADVANCE_DEVICE = 0x0040
    VALUE_FORMAT_Y_ADVANCE_DEVICE = 0x0080
    VALUE_FORMAT_RESERVED = 0xff00
end

@serializable struct ValueRecord
    @arg format::ValueFormat
    x_placement::Optional{Int16} << (in(VALUE_FORMAT_X_PLACEMENT, format) ? read(io, Int16) : nothing)
    y_placement::Optional{Int16} << (in(VALUE_FORMAT_Y_PLACEMENT, format) ? read(io, Int16) : nothing)
    x_advance::Optional{Int16} << (in(VALUE_FORMAT_X_ADVANCE, format) ? read(io, Int16) : nothing)
    y_advance::Optional{Int16} << (in(VALUE_FORMAT_Y_ADVANCE, format) ? read(io, Int16) : nothing)
    x_pla_device_offset::Optional{UInt16} << (in(VALUE_FORMAT_X_PLACEMENT_DEVICE, format) ? read(io, UInt16) : nothing)
    y_pla_device_offset::Optional{UInt16} << (in(VALUE_FORMAT_Y_PLACEMENT_DEVICE, format) ? read(io, UInt16) : nothing)
    x_adv_device_offset::Optional{UInt16} << (in(VALUE_FORMAT_X_ADVANCE_DEVICE, format) ? read(io, UInt16) : nothing)
    y_adv_device_offset::Optional{UInt16} << (in(VALUE_FORMAT_Y_ADVANCE_DEVICE, format) ? read(io, UInt16) : nothing)
end

abstract type AnchorTable end

@serializable struct AnchorTableFormat1 <: AnchorTable
    anchor_format::UInt16
    x_coordinate::Int16
    y_coordinate::Int16
end

@serializable struct AnchorTableFormat2 <: AnchorTable
    anchor_format::UInt16
    x_coordinate::Int16
    y_coordinate::Int16
    anchor_point::UInt16
end

@serializable struct AnchorTableFormat3 <: AnchorTable
    anchor_format::UInt16
    x_coordinate::Int16
    y_coordinate::Int16
    x_device_offset::UInt16
    y_device_offset::UInt16
end

function Base.read(io::IO, ::Type{AnchorTable})
    anchor_format = peek(io, UInt16)
    anchor_format == 1 ? read(io, AnchorTableFormat1) : anchor_format == 2 ? read(io, AnchorTableFormat2) : read(io, AnchorTableFormat3)
end

abstract type GPOSLookupSubtable{N} end

abstract type GPOSLookupSingleAdjustmentTable <: GPOSLookupSubtable{1} end

@serializable struct SingleAdjustmentTableFormat1 <: GPOSLookupSingleAdjustmentTable
    pos_format::UInt16
    coverage_offset::UInt16
    value_format::ValueFormat
    value_record::ValueRecord << read(io, ValueRecord, value_format)

    coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
end

@serializable struct SingleAdjustmentTableFormat2 <: GPOSLookupSingleAdjustmentTable
    pos_format::UInt16
    coverage_offset::UInt16
    value_format::ValueFormat
    value_count::UInt16
    value_records::Vector{ValueRecord} << [read(io, ValueRecord, value_format) for _ in 1:value_count]

    coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
end

function Base.read(io::IO, ::Type{GPOSLookupSubtable{1}})
    pos_format = peek(io, UInt16)
    pos_format == 1 ? read(io, SingleAdjustmentTableFormat1) : read(io, SingleAdjustmentTableFormat2)
end

abstract type GPOSLookupPairAdjustmentTable <: GPOSLookupSubtable{2} end

@serializable struct PairValueRecord
    @arg value_format_1
    @arg value_format_2
    second_glyph::GlyphID
    value_record_1::ValueRecord << read(io, ValueRecord, value_format_1)
    value_record_2::ValueRecord << read(io, ValueRecord, value_format_2)
end

@serializable struct PairSetTable
    @arg value_format_1
    @arg value_format_2
    pair_value_count::UInt16
    pair_value_record::Vector{PairValueRecord} << [read(io, PairValueRecord, value_format_1, value_format_2) for _ in 1:pair_value_count]
end

@serializable struct PairAdjustmentTableFormat1 <: GPOSLookupPairAdjustmentTable
    pos_format::UInt16
    coverage_offset::UInt16
    value_format_1::ValueFormat
    value_format_2::ValueFormat
    pair_set_count::UInt16
    pair_set_offsets::Vector{UInt16} => pair_set_count

    coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
    pair_set_tables::Vector{PairSetTable} << [read_at(io, PairSetTable, offset, value_format_1, value_format_2; start = __origin__) for offset in pair_set_offsets]
end

@serializable struct Class2Record
    @arg value_format_1
    @arg value_format_2
    value_record_1::ValueRecord << read(io, ValueRecord, value_format_1)
    value_record_2::ValueRecord << read(io, ValueRecord, value_format_2)
end

@serializable struct PairAdjustmentTableFormat2 <: GPOSLookupPairAdjustmentTable
    pos_format::UInt16
    coverage_offset::UInt16
    value_format_1::ValueFormat
    value_format_2::ValueFormat
    class_def_1_offset::UInt16
    class_def_2_offset::UInt16
    class_1_count::UInt16
    class_2_count::UInt16

    coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
    class_def_1_table::ClassDefinitionTable << read_at(io, ClassDefinitionTable, class_def_1_offset; start = __origin__)
    class_def_2_table::ClassDefinitionTable << read_at(io, ClassDefinitionTable, class_def_2_offset; start = __origin__)
    class_1_records::Vector{Vector{Class2Record}} << [[read(io, Class2Record, value_format_1, value_format_2) for _ in 1:class_2_count] for _ in 1:class_1_count]
end

function Base.read(io::IO, ::Type{GPOSLookupSubtable{2}})
    pos_format = peek(io, UInt16)
    pos_format == 1 ? read(io, PairAdjustmentTableFormat1) : read(io, PairAdjustmentTableFormat2)
end

@serializable struct EntryExitRecord
    entry_anchor_offset::UInt16
    exit_anchor_offset::UInt16
    entry_anchor_table::Optional{AnchorTable} << (iszero(entry_anchor_offset) ? nothing : read_at(io, AnchorTable, entry_anchor_offset; start = __origin__))
    exit_anchor_table::Optional{AnchorTable} << (iszero(exit_anchor_offset) ? nothing : read_at(io, AnchorTable, exit_anchor_offset; start = __origin__))
end

@serializable struct GPOSLookupCursiveAttachmentTable <: GPOSLookupSubtable{3}
    pos_format::UInt16
    coverage_offset::UInt16
    entry_exit_count::UInt16
    entry_exit_records::Vector{EntryExitRecord} => entry_exit_count

    coverage_table::CoverageTable << read_at(io, CoverageTable, coverage_offset; start = __origin__)
end

Base.read(io::IO, ::Type{GPOSLookupSubtable{3}}) = read(io, GPOSLookupCursiveAttachmentTable)

@serializable struct MarkRecord
    @arg start_mark_array_table
    mark_class::UInt16
    mark_anchor_offset::UInt16

    mark_anchor_table::AnchorTable << read_at(io, AnchorTable, mark_anchor_offset; start = start_mark_array_table)
end

@serializable struct MarkArrayTable
    mark_count::UInt16
    mark_records::Vector{MarkRecord} << [read(io, MarkRecord, __origin__) for _ in 1:mark_count]
end

@serializable struct BaseRecord
    @arg mark_class_count
    @arg start_base_array_table
    base_anchor_offsets::Vector{UInt16} => mark_class_count

    base_anchor_tables::Vector{Optional{AnchorTable}} << [iszero(offset) ? nothing : read_at(io, AnchorTable, offset; start = start_base_array_table) for offset in base_anchor_offsets]
end

@serializable struct BaseArrayTable
    @arg mark_class_count
    base_count::UInt16
    base_records::Vector{BaseRecord} << [read(io, BaseRecord, mark_class_count, __origin__) for _ in 1:base_count]
end

@serializable struct GPOSLookupMarkToBaseAttachmentTable <: GPOSLookupSubtable{4}
    pos_format::UInt16
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

Base.read(io::IO, ::Type{GPOSLookupSubtable{4}}) = read(io, GPOSLookupMarkToBaseAttachmentTable)

@serializable struct ComponentRecord
    @arg mark_class_count
    @arg start_ligature_attach_table
    ligature_anchor_offsets::Vector{UInt16} => mark_class_count

    ligature_anchor_tables::Vector{Optional{AnchorTable}} << [iszero(offset) ? nothing : read_at(io, AnchorTable, offset; start = start_ligature_attach_table) for offset in ligature_anchor_offsets]
end

@serializable struct LigatureAttachTable
    @arg mark_class_count
    component_count::UInt16
    component_records::Vector{ComponentRecord} << [read(io, ComponentRecord, mark_class_count, __origin__) for _ in 1:component_count]
end

@serializable struct LigatureArrayTable
    @arg mark_class_count
    ligature_count::UInt16
    ligature_attach_offsets::Vector{UInt16} => ligature_count

    ligature_attach_tables::Vector{LigatureAttachTable} << [read_at(io, LigatureAttachTable, offset, mark_class_count; start = __origin__) for offset in ligature_attach_offsets]
end

@serializable struct GPOSLookupMarkToLigatureAttachmentTable <: GPOSLookupSubtable{5}
    pos_format::UInt16
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

Base.read(io::IO, ::Type{GPOSLookupSubtable{5}}) = read(io, GPOSLookupMarkToLigatureAttachmentTable)

@serializable struct Mark2Record
    @arg mark_class_count
    @arg start_mark_2_array_table
    mark_2_anchor_offsets::Vector{UInt16} => mark_class_count

    mark_2_anchor_tables::Vector{Optional{AnchorTable}} << [ iszero(offset) ? nothing : read_at(io, AnchorTable, offset; start = start_mark_2_array_table) for offset in mark_2_anchor_offsets]
end

@serializable struct Mark2ArrayTable
    @arg mark_class_count
    mark_count::UInt16
    mark_records::Vector{Mark2Record} << [read(io, Mark2Record, mark_class_count, __origin__) for _ in 1:mark_count]
end

@serializable struct GPOSLookupMarkToMarkAttachmentTable <: GPOSLookupSubtable{6}
    pos_format::UInt16
    mark_1_coverage_offset::UInt16
    mark_2_coverage_offset::UInt16
    mark_class_count::UInt16
    mark_1_array_offset::UInt16
    mark_2_array_offset::UInt16

    mark_1_coverage_table::CoverageTable << read_at(io, CoverageTable, mark_1_coverage_offset; start = __origin__)
    mark_2_coverage_table::CoverageTable << read_at(io, CoverageTable, mark_2_coverage_offset; start = __origin__)
    mark_1_array_table::MarkArrayTable << read_at(io, MarkArrayTable, mark_1_array_offset; start = __origin__)
    mark_2_array_table::Mark2ArrayTable << read_at(io, Mark2ArrayTable, mark_2_array_offset, mark_class_count; start = __origin__)
end

Base.read(io::IO, ::Type{GPOSLookupSubtable{6}}) = read(io, GPOSLookupMarkToMarkAttachmentTable)

@serializable struct GPOSContextualTable <: GPOSLookupSubtable{7}
    table::SequenceContextTable
end

Base.read(io::IO, ::Type{GPOSLookupSubtable{7}}) = read(io, GPOSContextualTable)

@serializable struct GPOSChainedContextualTable <: GPOSLookupSubtable{8}
    table::ChainedSequenceContextTable
end

Base.read(io::IO, ::Type{GPOSLookupSubtable{8}}) = read(io, GPOSChainedContextualTable)

@serializable struct GPOSLookupTable <: LookupTable
    lookup_type::UInt16
    lookup_flag::LookupFlag
    subtable_count::UInt16
    subtable_offsets::Vector{UInt16} => subtable_count
    mark_filtering_set::UInt16

    subtables::Vector{GPOSLookupSubtable} << [read_at(io, GPOSLookupSubtable{Int(lookup_type)}, offset; start = __origin__) for offset in subtable_offsets]
end

@serializable struct GPOSExtenstionTable <: GPOSLookupSubtable{9}
    pos_format::UInt16
    extension_lookup_type::UInt16
    extension_offset::UInt16

    extension_table::GPOSLookupTable << read_at(io, GPOSLookupTable, extension_offset; start = __origin__)
end

Base.read(io::IO, ::Type{GPOSLookupSubtable{9}}) = read(io, GPOSExtenstionTable)

@serializable struct GlyphPositioningTable
    header::GPOSHeader
    script_list_table::ScriptListTable << read_at(io, ScriptListTable, header.script_list_offset; start = __origin__)
    feature_list_table::FeatureListTable << read_at(io, FeatureListTable, header.feature_list_offset; start = __origin__)
    lookup_list_table::LookupListTable << read_at(io, LookupListTable, header.lookup_list_offset, GPOSLookupTable; start = __origin__)
end

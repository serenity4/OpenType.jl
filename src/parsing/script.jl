@serializable struct LangSysTable
    lookup_order_offset::UInt16
    required_feature_index::UInt16
    feature_index_count::UInt16
    feature_indices::Vector{UInt16} => feature_index_count
end

@serializable struct LangSysRecord
    @arg script_table_origin
    lang_sys_tag::Tag
    lang_sys_offset::UInt16
    lang_sys_table::LangSysTable << read_at(io, LangSysTable, lang_sys_offset; start = script_table_origin)
end

@serializable struct ScriptTable
    default_lang_sys_offset::UInt16
    lang_sys_count::UInt16
    lang_sys_record::Vector{LangSysRecord} << [read(io, LangSysRecord, __origin__) for _ in 1:lang_sys_count]
    default_lang_sys::Optional{LangSysRecord} << (iszero(default_lang_sys_offset) ? nothing : read_at(io, LangSysRecord, default_lang_sys_offset, __origin__))
end

@serializable struct ScriptRecord
    @arg script_list_table_origin
    script_tag::Tag
    script_offset::UInt16
    script_table::ScriptTable << read_at(io, ScriptTable, script_offset; start = script_list_table_origin)
end

@serializable struct ScriptListTable
    script_count::UInt16
    script_records::Vector{ScriptRecord} << [read(io, ScriptRecord, __origin__) for _ in 1:script_count]
end

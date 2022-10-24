@serializable struct LangSysTable
    lookup_order_offset::UInt16 << begin
        val = read(io, UInt16)
        @assert iszero(val) "Non-zero value detected for reserved field 'lookup_order_offset'"
        val
    end
    required_feature_index::UInt16
    feature_index_count::UInt16
    feature_indices::Vector{UInt16} => feature_index_count
end

@serializable struct LangSysRecord
    @arg script_table_origin
    lang_sys_tag::Tag{4}
    lang_sys_offset::UInt16
    lang_sys_table::LangSysTable << read_at(io, LangSysTable, lang_sys_offset; start = script_table_origin)
end

@serializable struct ScriptTable
    default_lang_sys_offset::UInt16
    lang_sys_count::UInt16
    lang_sys_records::Vector{LangSysRecord} << [read(io, LangSysRecord, __origin__) for _ in 1:lang_sys_count]
    default_lang_sys_table::Optional{LangSysTable} << (iszero(default_lang_sys_offset) ? nothing : read_at(io, LangSysTable, default_lang_sys_offset; start = __origin__))
end

@serializable struct ScriptRecord
    @arg script_list_table_origin
    script_tag::Tag{4}
    script_offset::UInt16
    script_table::ScriptTable << read_at(io, ScriptTable, script_offset; start = script_list_table_origin)
end

@serializable struct ScriptListTable
    script_count::UInt16
    script_records::Vector{ScriptRecord} << [read(io, ScriptRecord, __origin__) for _ in 1:script_count]
end

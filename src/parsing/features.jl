@serializable struct FeatureTable
    feature_params_offset::UInt16
    lookup_index_count::UInt16
    lookup_list_indices::Vector{UInt16} => lookup_index_count
end

@serializable struct FeatureRecord
    @arg feature_list_table_origin
    feature_tag::Tag
    feature_offset::UInt16
    feature_table::FeatureTable << read_at(io, FeatureTable, feature_offset; start = feature_list_table_origin)
end

@serializable struct FeatureListTable
    feature_count::UInt16
    feature_records::Vector{FeatureRecord} << [read(io, FeatureRecord, __origin__) for _ in 1:feature_count]
end

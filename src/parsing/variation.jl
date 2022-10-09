@serializable struct AxisValueMap
    from_coordinate::Int16
    to_coordinate::Int16
end

@serializable struct AxisSegmentMapRecord
    position_map_count::UInt16
    axis_value_maps::Vector{AxisValueMap} => position_map_count
end

@serializable struct AxisVariationsTable
    major_version::UInt16
    minor_version::UInt16
    reserved::UInt16
    axis_count::UInt16
    axis_segment_maps::Vector{AxisSegmentMapRecord} => axis_count
end

@serializable struct FontVariationsHeader
    major_version::UInt16
    minor_version::UInt16
    axes_array_offset::UInt16
    reserved::UInt16
    axis_count::UInt16
    axis_size::UInt16
    instance_count::UInt16
    instance_size::UInt16
end

@bitmask AxisQualifierFlag::UInt16 begin
    AXIS_QUALIFIER_HIDDEN_AXIS = 0x0001
    AXIS_QUALIFIER_RESERVED = 0xfffe
end

@serializable struct VariationAxisRecord
    tag::Tag
    min_value::Fixed
    default_value::Fixed
    max_value::Fixed
    flags::AxisQualifierFlag
    axis_name_id::UInt16
end

@serializable struct InstanceRecord
    @arg axis_count
    @arg instance_size
    subfamily_name_id::UInt16
    flags::UInt16
    coordinates::Vector{Fixed} => axis_count
    post_script_name_id::Optional{UInt16} << (instance_size == position(io) - __origin__ ? nothing : read(io, UInt16))
end

@serializable struct FontVariationsTable
    header::FontVariationsHeader
    axes::Vector{VariationAxisRecord} => header.axis_count
    instances::Vector{InstanceRecord} << [read(io, InstanceRecord, header.axis_count, header.instance_size) for _ in 1:header.instance_count]
end

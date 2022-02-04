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

const Fixed = UInt32

@bitmask_flag AxisQualifierFlag::UInt16 begin
    AXIS_QUALIFIER_HIDDEN_AXIS = 0x0001
    AXIS_QUALIFIER_RESERVED = 0xfffe
end

struct VariationAxisRecord
    tag::String
    min_value::Fixed
    default_value::Fixed
    max_value::Fixed
    flags::AxisQualifierFlag
    axis_name_id::UInt16
end

struct InstanceRecord
    subfamily_name_id::UInt16
    flags::UInt16
    coordinates::Vector{Fixed}
    post_script_name_id::UInt16
end

struct FontVariationsTable
    header::FontVariationsHeader
    axes::Vector{VariationAxisRecord} => header.axis_count
    instances::Vector{InstanceRecord} => header.instance_count
end

function Base.read(io::IO, ::Type{FontVariationsTable})
    header = read(io, FontVariationsHeader)
    error("Not yet functional, currently WIP.")
    axes = [read(io, VariationAxisRecord) for _ in 1:header.axis_count]
    instances = InstanceRecord[]
    for i in 1:(header.instance_count + 1)
        subfamily_name_id = read(io, UInt16)
        flags = read(io, UInt16)
        coordinates = map(1:(header.axis_count + 1)) do _
            read(io, Fixed)
        end
        post_script_name_id = read(io, UInt16)
        push!(instances, InstanceRecord(subfamily_name_id, flags, coordinates, post_script_name_id))
    end
    FontVariationsTable(header, axes, instances)
end

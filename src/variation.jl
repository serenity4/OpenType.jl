"""
Remap a value from [a, b] to [a′, b′].
"""
function remap(value, a, b, a′, b′)
    a′ + (value - a) * (b′ - a′) / (b - a)
end

struct SegmentMap
    from::Int16
    to::Int16
end

struct VariationAxis
    min::Int16
    default::Int16
    max::Int16
    scale::Float64
    name::String
    segments::Vector{SegmentMap}
end

function default_normalized_value(coord, min, default, max)
    if coord <= default
        remap(max(coord, min), min, default, -1., 0.)
    else
        remap(min(coord, max), default, max, 0., 1.)
    end
end

"""
Map a variation coordinate in user space into its normalized space [-1, 1].
"""
function normalized_value(value, axis::VariationAxis)
    default = default_normalized_value(value, axis.min, axis.max, axis.default)
    seg_idx = findfirst(seg -> seg.from ≥ value, axis.segments)
    isnothing(seg_idx) && return default
    seg_end = axis.segments[seg_idx]
    seg_end.from == default && return seg_end.to
    seg_start = axis.segments[seg_idx - 1]
    remap(default, seg_start.from, seg_end.from, seg_start.to, seg_end.to)
end

struct VariationInfo
    axes::Dict{String,VariationAxis}
end

function VariationInfo(data::OpenTypeData)
    
end

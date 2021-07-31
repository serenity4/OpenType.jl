struct HorizontalHeader
    ascender::Int16
    descender::Int16
    line_gap::Int16
    advance_width_max::UInt16
    min_left_side_bearing::Int16
    min_right_side_bearing::Int16
    x_max_extent::Int16
    caret_slope_rise::Int16
    caret_slope_run::Int16
    caret_offset::Int16
    metric_data_format::Int16
    nhmetrics::UInt16
end

function Base.parse(io::IO, ::Type{HorizontalHeader})
    major = read(io, UInt16)
    minor = read(io, UInt16)
    @assert VersionNumber(major, minor) == v"1.0"
    hhea = HorizontalHeader(
        [read(io, T) for T in fieldtypes(HorizontalHeader)[1:10]]...,
        (skip(io, 8); read(io, Int16)),
        read(io, UInt16),
    )
    @assert hhea.metric_data_format == 0 "Metric data format should be zero, got $(hhea.metric_data_format)"
    hhea
end

struct VerticalHeader
    ascent::Int16
    descent::Int16
    line_gap::Int16
    advance_height_max::Int16
    min_top_side_bearing::Int16
    min_bottom_side_bearing::Int16
    y_max_extent::Int16
    caret_slope_rise::Int16
    caret_slope_run::Int16
    caret_offset::Int16
    metric_data_format::Int16
    nvmetrics::UInt16
end

function Base.parse(io::IO, ::Type{VerticalHeader})
    skip(io, 4)
    VerticalHeader(
        [read(io, T) for T in fieldtypes(VerticalHeader)[1:10]]...,
        (skip(io, 8); read(io, Int16)),
        read(io, UInt16),
    )
end

struct HorizontalMetric
    advance_width::UInt16
    left_side_bearing::Int16
end

struct HorizontalMetrics
    metrics::Vector{HorizontalMetric}
    left_side_bearings::Vector{Int16}
end

Base.read(io::IO, ::Type{HorizontalMetric}) = HorizontalMetric(read(io, UInt16), read(io, Int16))

function Base.parse(io::IO, ::Type{HorizontalMetrics}, hhea::HorizontalHeader, maxp::MaximumProfile)
    metrics = [read(io, HorizontalMetric) for _ in 1:hhea.nhmetrics]
    left_side_bearings = [read(io, Int16) for _ in 1:(maxp.nglyphs - hhea.nhmetrics)]
    HorizontalMetrics(metrics, left_side_bearings)
end

struct VerticalMetric
    advance_width::UInt16
    top_side_bearing::Int16
end

struct VerticalMetrics
    metrics::Vector{VerticalMetric}
    top_side_bearings::Vector{Int16}
end

Base.read(io::IO, ::Type{VerticalMetric}) = VerticalMetric(read(io, UInt16), read(io, Int16))

function Base.parse(io::IO, ::Type{VerticalMetrics}, vhea::VerticalHeader, maxp::MaximumProfile)
    metrics = [read(io, VerticalMetric) for _ in 1:vhea.nvmetrics]
    top_side_bearings = [read(io, Int16) for _ in 1:(maxp.nglyphs - vhea.nvmetrics)]
    VerticalMetrics(metrics, top_side_bearings)
end

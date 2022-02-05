@serializable struct HorizontalHeader
    major_version::UInt16
    minor_version::UInt16
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
    reserved_1::Int16
    reserved_2::Int16
    reserved_3::Int16
    reserved_4::Int16
    metric_data_format::Int16
    number_of_h_metrics::UInt16
end

"""
Vertical header.

Note that, if the version is 1.0 (0x00010000),
then `vert_typo_ascender`, `vert_typo_descender`
and `vert_typo_line_gap` have a meaning of `ascent`,
`descent` and `line_gap` as described in the [specification](https://docs.microsoft.com/en-us/typography/opentype/spec/vhea#table-format).
"""
@serializable struct VerticalHeader
    version::UInt32
    vert_typo_ascender::Int16
    vert_typo_descender::Int16
    vert_typo_line_gap::Int16
    advance_height_max::Int16
    min_top_side_bearing::Int16
    min_bottom_side_bearing::Int16
    y_max_extent::Int16
    caret_slope_rise::Int16
    caret_slope_run::Int16
    caret_offset::Int16
    reserved_1::Int16
    reserved_2::Int16
    reserved_3::Int16
    reserved_4::Int16
    metric_data_format::Int16
    num_of_long_ver_metrics::UInt16
end

@serializable struct HorizontalMetric
    advance_width::UInt16
    left_side_bearing::Int16
end

struct HorizontalMetrics
    metrics::Vector{HorizontalMetric}
    left_side_bearings::Vector{Int16}
end

function Base.read(io::IO, ::Type{HorizontalMetrics}, hhea::HorizontalHeader, maxp::MaximumProfile)
    metrics = [read(io, HorizontalMetric) for _ in 1:hhea.number_of_h_metrics]
    left_side_bearings = [read(io, Int16) for _ in 1:(maxp.nglyphs - hhea.number_of_h_metrics)]
    HorizontalMetrics(metrics, left_side_bearings)
end

@serializable struct VerticalMetric
    advance_width::UInt16
    top_side_bearing::Int16
end

struct VerticalMetrics
    metrics::Vector{VerticalMetric}
    top_side_bearings::Vector{Int16}
end

function Base.read(io::IO, ::Type{VerticalMetrics}, vhea::VerticalHeader, maxp::MaximumProfile)
    metrics = [read(io, VerticalMetric) for _ in 1:vhea.num_of_long_ver_metrics]
    top_side_bearings = [read(io, Int16) for _ in 1:(maxp.nglyphs - vhea.num_of_long_ver_metrics)]
    VerticalMetrics(metrics, top_side_bearings)
end

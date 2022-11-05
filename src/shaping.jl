"""
Direction of a particular piece of text.

This direction should be computed from the Unicode Character Database (UCD), using character metadata.
"""
@enum Direction::UInt8 begin
  DIRECTION_LEFT_TO_RIGHT = 1
  DIRECTION_RIGHT_TO_LEFT = 2
  DIRECTION_TOP_TO_BOTTOM = 3
  DIRECTION_BOTTOM_TO_TOP = 4
end

function horizontal_metric(hmtx::HorizontalMetrics, glyph::GlyphID)
  (; metrics, left_side_bearings) = hmtx
  i = glyph + 1
  i > length(metrics) && return HorizontalMetric(last(metrics).advance_width, left_side_bearings[i - length(metrics)])
  metrics[i]
end

function vertical_metric(vtmx::VerticalMetrics, glyph::GlyphID)
  (; metrics, top_side_bearings) = vmtx
  i = glyph + 1
  i > length(metrics) && return VerticalMetric(last(metrics).advance_width, top_side_bearings[i - length(metrics)])
  metrics[i]
end

function metric_offset(font::OpenTypeFont, glyph::GlyphID, direction::Direction)
  if direction == DIRECTION_LEFT_TO_RIGHT || direction == DIRECTION_RIGHT_TO_LEFT
    !isnothing(font.hmtx) || error("No horizontal metrics present for the provided font.")
    metric = horizontal_metric(font.hmtx, glyph)
    GlyphOffset(Point(0, 0), Point(metric.advance_width, 0))
  else
    !isnothing(font.vmtx) || error("No vertical metrics present for the provided font.")
    metric = vertical_metric(font.vmtx, glyph, direction)
    GlyphOffset(Point(0, 0), Point(0, metric.advance_width))
  end
end

function compute_advances!(offsets::AbstractVector{GlyphOffset}, font::OpenTypeFont, glyph_ids, direction::Direction)
  for i in eachindex(offsets)
    offsets[i] += metric_offset(font, glyph_ids[i], direction)
  end
end

struct ShapingOptions
  "OpenType or ISO-15924 script tag."
  script::Tag{4}
  "ISO-639-1, ISO-639-3 or OpenType language tag."
  language::Union{Tag{2},Tag{3},Tag{4}}
  direction::Direction
  disabled_features::Set{Tag{4}}
end

ShapingOptions(script, language, direction::Direction = DIRECTION_LEFT_TO_RIGHT; disabled_features = Tag{4}[]) = ShapingOptions(script, language, direction, Set(@something(disabled_features, Tag{4}[])))

struct SubstitutionInfo
  type::SubstitutionRuleType
  replacement::Optional{Pair{Union{GlyphID, Vector{GlyphID}}, Union{GlyphID, Vector{GlyphID}}}}
  index::Int
  range::Int
  glyph::GlyphID
end

struct PositioningInfo
  type::PositioningRuleType
  offsets::Pair{Union{GlyphID, Vector{GlyphID}}, Union{GlyphOffset, Vector{GlyphOffset}}}
  index::Int
  range::UnitRange{Int}
  glyph::GlyphID
end

struct ShapingInfo
  substitutions::Vector{SubstitutionInfo}
  positionings::Vector{PositioningInfo}
end

ShapingInfo() = ShapingInfo([], [])

function record_substitution!(info::ShapingInfo, (; type)::SubstitutionRule, glyphs, i, ret, range)
  @assert in(i, range)
  replaced = length(range) == 1 ? glyphs[i] : glyphs[range]
  pair = isnothing(ret) ? nothing : replaced => ret
  push!(info.substitutions, SubstitutionInfo(type, pair, i, range, glyphs[i]))
end

function record_positioning!(info::ShapingInfo, (; type)::PositioningRule, glyphs, i, ret, range)
  @assert in(i, range)
  affected = length(range) == 1 ? glyphs[i] : glyphs[range]
  pair = isnothing(ret) ? nothing : affected => ret
  push!(info.positionings, PositioningInfo(type, pair, i, range, glyphs[i]))
end

shape(font::OpenTypeFont, text::AbstractString, options::ShapingOptions; info::Optional{ShapingInfo} = nothing) = shape(font, collect(text), options; info)

function shape(font::OpenTypeFont, chars::AbstractVector{Char}, options::ShapingOptions; info::Optional{ShapingInfo} = nothing)
  glyph_ids = glyph_index.(font, chars)

  # Glyph substitution.
  callback = isnothing(info) ? nothing : (args...) -> record_substitution!(info, args...)
  apply_substitution_rules!(glyph_ids, font.gsub, font.gdef, options.script, options.language, options.disabled_features, (glyph, alts) -> glyph, callback)

  # Glyph positioning.
  offsets = zeros(GlyphOffset, length(glyph_ids))
  compute_advances!(offsets, font, glyph_ids, options.direction)
  callback = isnothing(info) ? nothing : (args...) -> record_positioning!(info, args...)
  apply_positioning_rules!(offsets, font.gpos, font.gdef, glyph_ids, options.script, options.language, options.disabled_features, callback)

  glyph_ids, offsets
end

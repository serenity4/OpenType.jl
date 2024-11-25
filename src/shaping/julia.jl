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
  if ishorizontal(direction)
    !isnothing(font.hmtx) || error("No horizontal metrics present for the provided font.")
    metric = horizontal_metric(font.hmtx, glyph)
    GlyphOffset(Vec(0, 0), Vec(metric.advance_width, 0))
  else
    !isnothing(font.vmtx) || error("No vertical metrics present for the provided font.")
    metric = vertical_metric(font.vmtx, glyph, direction)
    GlyphOffset(Vec(0, 0), Vec(0, metric.advance_width))
  end
end

function compute_advances!(offsets::AbstractVector{GlyphOffset}, font::OpenTypeFont, glyph_ids, direction::Direction)
  for i in eachindex(offsets)
    offsets[i] += metric_offset(font, glyph_ids[i], direction)
  end
end

struct SubstitutionInfo
  feature::Tag4
  type::SubstitutionRuleType
  replacement::Optional{Pair{Union{GlyphID, Vector{GlyphID}}, Union{GlyphID, Vector{GlyphID}}}}
  index::Int
  range::UnitRange{Int}
  glyph::GlyphID
end

struct PositioningInfo
  feature::Tag4
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

function record_substitution!(info::ShapingInfo, (; type)::SubstitutionRule, (; tag)::Feature, glyphs, i, ret, range)
  @assert in(i, range)
  replaced = length(range) == 1 ? glyphs[i] : glyphs[range]
  pair = isnothing(ret) ? nothing : replaced => ret
  push!(info.substitutions, SubstitutionInfo(tag, type, pair, i, range, glyphs[i]))
end

function record_positioning!(info::ShapingInfo, (; type)::PositioningRule, (; tag)::Feature, glyphs, i, ret, range)
  @assert in(i, range)
  affected = length(range) == 1 ? glyphs[i] : glyphs[range]
  pair = isnothing(ret) ? nothing : affected => ret
  push!(info.positionings, PositioningInfo(tag, type, pair, i, range, glyphs[i]))
end

jl_shape(font::OpenTypeFont, text::AbstractString, options::ShapingOptions; info::Optional{ShapingInfo} = nothing) = jl_shape(font, collect(text), options; info)

jl_shape(font::OpenTypeFont, chars::AbstractVector{Char}, options::ShapingOptions; info::Optional{ShapingInfo} = nothing) =
  jl_shape(font, glyph_index.(font, chars), options; info)
function jl_shape(font::OpenTypeFont, glyphs::AbstractVector{GlyphID}, options::ShapingOptions; info::Optional{ShapingInfo} = nothing)
  # Glyph substitution.
  if !isnothing(font.gsub)
    callback = isnothing(info) ? nothing : (args...) -> record_substitution!(info, args...)
    apply_substitution_rules!(glyphs, font.gsub, font.gdef, options.script, options.language, options.enabled_features, options.disabled_features, options.direction, (glyph, alts) -> glyph, callback)
  end

  # Glyph positioning.
  offsets = zeros(GlyphOffset, length(glyphs))
  compute_advances!(offsets, font, glyphs, options.direction)
  if !isnothing(font.gpos)
    callback = isnothing(info) ? nothing : (args...) -> record_positioning!(info, args...)
    apply_positioning_rules!(offsets, font.gpos, font.gdef, glyphs, options.script, options.language, options.enabled_features, options.disabled_features, options.direction, callback)
  end

  glyphs, offsets
end

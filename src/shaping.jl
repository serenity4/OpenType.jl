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

shape(font::OpenTypeFont, text::AbstractString, options::ShapingOptions) = shape(font, collect(text), options)

function shape(font::OpenTypeFont, chars::AbstractVector{Char}, options::ShapingOptions)
  glyph_ids = glyph_index.(font, chars)
  # TODO: Perform glyph substitutions.
  offsets = zeros(GlyphOffset, length(glyph_ids))
  compute_advances!(offsets, font, glyph_ids, options.direction)
  apply_positioning_rules!(offsets, font.gpos, glyph_ids, options.script, options.language, options.disabled_features)
  glyph_ids, offsets
end

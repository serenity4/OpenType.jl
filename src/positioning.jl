struct PositioningRuleImpl
  data::Any
end

struct PositioningRule
  type::UInt16
  flag::UInt16
  "Rule implementations. There can be several depending on storage efficiency."
  rule_impls::Vector{PositioningRuleImpl}
end

struct GlyphPositioning
  scripts::Dict{Tag,Script}
  features::Vector{Feature}
  rules::Vector{PositioningRule}
end

function GlyphPositioning(gpos::GlyphPositioningTable)
  scripts = Dict(script.tag => script for script in Script.(gpos.script_list_table.script_records))
  features = Feature.(gpos.feature_list_table.feature_records)
  rules = []
  GlyphPositioning(scripts, features, [])
end

function positioning_features(gpos::GlyphPositioning, script_tag::Tag, language_tag::Tag, disabled_features::Set{Tag})
  language = LanguageSystem(script_tag, language_tag, gpos.scripts)
  features = gpos.features[language.feature_indices .+ 1]
  filter!(x -> !in(x.tag, disabled_features), features)
  language.required_feature_index ≠ typemax(UInt16) && pushfirst!(features, gpos.features[language.required_feature_index + 1])
  features
end

function glyph_offsets(gpos::GlyphPositioning, glyphs, script_tag::Tag, language_tag::Tag, disabled_features::Set{Tag})
  apply_positioning_features(gpos, glyph, positioning_features(gpos, script_tag, language_tag, disabled_features))
end

function positioning_rules(gpos::GlyphPositioning, features::Vector{Feature})
  indices = sort!(foldl((x, y) -> vcat(x, y.rule_indices), features; init = UInt16[]))
  @view gpos.rules[indices .- 1]
end

struct GlyphOffset
  "Offset to the origin of the glyph."
  origin::Point{2,Int16}
  "Offset to the advance that will be applied to the pen position after writing the glyph to proceed to the next one."
  advance::Point{2,Int16}
end

Base.zero(::Type{GlyphOffset}) = GlyphOffset(zero(Point{2,Int16}), zero(Point{2,Int16}))
Base.:(+)(x::GlyphOffset, y::GlyphOffset) = GlyphOffset(x.origin + y.origin, x.advance + y.advance)

function glyph_offsets(gpos::GlyphPositioning, glyphs, features::Vector{Feature})
  origin = zero(Point{2,Int16})
  advance = zero(Point{2,Int16})
  glyph_offsets = zeros(GlyphOffset, length(glyphs))
  for rule in positioning_rules(gpos, features)
    for (i, glyph) in enumerate(glyphs)
      glyph_offsets[i] += glyph_offset(gpos, glyphs, glyph, rule)
    end
  end
  glyph_offsets
end

struct AdjustmentPositioning
  coverage::Coverage
  positions::Union{GlyphOffset,Vector{GlyphOffset}}
end

function apply_positioning_rule(gpos::GlyphPositioning, glyph::GlyphID, pattern::AdjustmentPositioning)
  i = match(pattern.coverage, glyph)
  !isnothing(i) && return isa(pattern.positions, GlyphOffset) ? pattern.positions : pattern.positions[i]
  nothing
end

struct PairAdjustmentPositioning
  coverage::Coverage
  pairs::Dict{GlyphID, Pair{GlyphOffset,GlyphOffset}}
end

function apply_positioning_rule(gpos::GlyphPositioning, glyph::GlyphID, pattern::PairAdjustmentPositioning)
  i = match(pattern.coverage, glyph)
  !isnothing(i) && return pattern.pairs[glyph]
  nothing
end

const AnchorPoint = Point{2,Int16}

struct MarkAnchor
  class::Int
  anchor::AnchorPoint
end

struct MarkToBaseRule
  mark_coverage::Coverage
  base_coverage::Coverage
  base_anchor_indices::Vector{Vector{AnchorPoint}} # indexed by base coverage index and then by mark class
  mark_anchors::Vector{MarkAnchor} # indexed by mark coverage index
end

function apply_positioning_rule(gpos::GlyphPositioning, (mark, base)::Pair{GlyphID}, rule::MarkToBaseRule)
  i = match(rule.mark_coverage, mark)
  isnothing(i) && return
  j = match(rule.base_coverage, base)
  isnothing(j) && return
  mark_anchor = rule.mark_anchors[i]
  base_anchor = rule.base_anchor_indices[j][mark_anchor.class]
  base_anchor - mark_anchor
end

# -----------------------------------
# Conversions from serializable types

function PairAdjustmentPositioning(table::PairAdjustmentTableFormat1)
  pairs = Dict{GlyphID, Pair{GlyphOffset, GlyphOffset}}()
  for set in table.pair_set_tables
    for pair in set.pair_value_records
      pairs[pair.second_glyph] = GlyphOffset(pair.value_record_1) => GlyphOffset(pair.value_record_2)
    end
  end
  PairAdjustmentPositioning(table.coverage_table, pairs)
end

function GlyphOffset(value::ValueRecord)
  origin = Point{2,Int16}(something(value.x_placement, 0), something(value.y_placement, 0))
  advance = Point{2,Int16}(something(value.x_advance, 0), something(value.y_advance, 0))
  GlyphOffset(origin, advance)
end

anchor(table::AnchorTable) = Point(table.x_coordinate, table.y_coordinate)

function MarkToBaseRule(table::GPOSLookupMarkToBaseAttachmentTable)
  base_anchor_indices = table.base_array_table.base_records
  mark_anchors = [MarkAnchor(record.mark_class, anchor(record.mark_anchor_table) for record in table.mark_array_table.mark_records)]
  MarkToBaseRule(table.mark_coverage_table, table.base_coverage_table, base_anchor_indices, mark_anchors)
end

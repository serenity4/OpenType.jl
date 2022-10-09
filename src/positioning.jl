@enum PositioningRuleType::UInt8 begin
  POSITIONING_RULE_ADJUSTMENT = 1
  POSITIONING_RULE_PAIR_ADJUSTMENT = 2
  POSITIONING_RULE_CURSIVE = 3
  POSITIONING_RULE_MARK_TO_BASE = 4
  POSITIONING_RULE_MARK_TO_LIGATURE = 5
  POSITIONING_RULE_MARK_TO_MARK = 6
  POSITIONING_RULE_CONTEXTUAL = 7
  POSITIONING_RULE_CONTEXTUAL_CHAINED = 8
end

struct PositioningRuleImpl
  type::PositioningRuleType
  impl::Any
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

function glyph_offsets(gpos::GlyphPositioning, glyph, script_tag::Tag, language_tag::Tag, disabled_features::Set{Tag})
  glyph_offsets(gpos, glyphs, positioning_features(gpos, script_tag, language_tag, disabled_features))
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
  glyph_offsets = zeros(GlyphOffset, length(glyphs))
  for rule in positioning_rules(gpos, features)
    for i in eachindex(glyphs)
      apply_positioning_rule!(glyph_offsets, rule, gpos, glyphs, i)
    end
  end
  glyph_offsets
end

function apply_positioning_rule!(glyph_offsets, rule::PositioningRule, gpos::GlyphPositioning, glyphs, i)
  for subrule in rule.rule_impls
    apply_positioning_rule!(glyph_offsets, subrule, gpos, glyphs, i)
  end
end

function positioning_rules(gpos::GlyphPositioning, features::Vector{Feature})
  indices = sort!(foldl((x, y) -> vcat(x, y.rule_indices), features; init = UInt16[]))
  @view gpos.rules[indices .- 1]
end

function apply_positioning_rule!(glyph_offsets, rule::PositioningRuleImpl, gpos::GlyphPositioning, i, glyphs, ligature_component::Optional{Int})
  (; type) = rule
  if type == POSITIONING_RULE_ADJUSTMENT
    offset = apply_positioning_rule(glyphs[i], rule.impl::AdjustmentPositioning)
    !isnothing(offset) && (glyph_offsets[i] += offset)
  elseif in(type, (POSITIONING_RULE_PAIR_ADJUSTMENT, POSITIONING_RULE_MARK_TO_BASE)) && i < lastindex(glyphs)
    ret = apply_positioning_rule(glyphs[i] => glyphs[i + 1], rule.impl::Union{PairAdjustmentPositioning, ClassPairAdjustmentPositioning})
    if !isnothing(ret)
      glyph_offsets[i] += ret.first
      glyph_offsets[i + 1] += ret.second
    end
  elseif in(type, (POSITIONING_RULE_CURSIVE, POSITIONING_RULE_MARK_TO_BASE, POSITIONING_RULE_MARK_TO_LIGATURE, POSITIONING_RULE_MARK_TO_MARK)) && i > firstindex(glyphs)
    offset = if type == POSITIONING_RULE_MARK_TO_LIGATURE
      apply_positioning_rule(glyphs[i - 1] => glyphs[i], rule.impl::MarkToLigatureRule, ligature_component::Int)
    else
      apply_positioning_rule(glyphs[i - 1] => glyphs[i], rule.impl::Union{CursivePositioningRule, MarkToBaseRule, MarkToMarkRule})
    end
    !isnothing(offset) && (glyph_offsets[i] += offset)
  elseif type == POSITIONING_RULE_CONTEXTUAL
    # TODO
  elseif type == POSITIONING_RULE_CONTEXTUAL_CHAINED
    # TODO
  end
end

struct AdjustmentPositioning
  coverage::Coverage
  positions::Union{GlyphOffset,Vector{GlyphOffset}}
end

function apply_positioning_rule(glyph::GlyphID, pattern::AdjustmentPositioning)
  i = match(pattern.coverage, glyph)
  !isnothing(i) && return isa(pattern.positions, GlyphOffset) ? pattern.positions : pattern.positions[i]
  nothing
end

struct PairAdjustmentPositioning
  coverage::Coverage
  pairs::Dict{GlyphID, Pair{GlyphOffset,GlyphOffset}}
end

function apply_positioning_rule((first, second)::Pair{GlyphID}, pattern::PairAdjustmentPositioning)
  contains(pattern.coverage, glyph) && return get(pattern.pairs, glyph, nothing)
  nothing
end

struct ClassPairAdjustmentPositioning
  coverage::Coverage
  class_first::ClassDefinition
  class_second::ClassDefinition
  pairs::Vector{Vector{Pair{GlyphOffset, GlyphOffset}}} # by 0-based index into first then second class definition
end

function apply_positioning_rule((first, second)::Pair{GlyphID}, pattern::ClassPairAdjustmentPositioning)
  !contains(pattern.coverage, glyph) && return nothing
  c1 = class(first, pattern.class_first)
  c2 = class(second, pattern.class_second)
  pattern.pairs[c1 + 1][c2 + 1]
end

const AnchorPoint = Point{2,Int16}

struct MarkAnchor
  class::ClassID
  anchor::AnchorPoint
end

struct CursivePositioningRule
  coverage::Coverage
  entry_exits::Vector{Pair{Optional{AnchorPoint},Optional{AnchorPoint}}}
end

function apply_positioning_rule((current, next)::Pair{GlyphID}, rule::CursivePositioningRule)
  i = match(rule.coverage, current)
  isnothing(i) && return nothing
  j = match(rule.coverage, next)
  isnothing(j) && return nothing
  current_exit = rule.entry_exits[i].second
  next_entry = rule.entry_exits[j].first
  (isnothing(current_exit) || isnothing(next_entry)) && return nothing
  next_entry - current_exit
end

struct MarkToBaseRule
  mark_coverage::Coverage
  base_coverage::Coverage
  base_anchor_indices::Vector{Vector{Optional{AnchorPoint}}} # indexed by base coverage index and then by 0-based mark class
  mark_anchors::Vector{MarkAnchor} # indexed by mark coverage index
end

function apply_positioning_rule((mark, base)::Pair{GlyphID}, rule::MarkToBaseRule)
  i = match(rule.mark_coverage, mark)
  isnothing(i) && return nothing
  j = match(rule.base_coverage, base)
  isnothing(j) && return nothing
  mark_anchor = rule.mark_anchors[i]
  base_anchor = rule.base_anchor_indices[j][mark_anchor.class + 1]
  isnothing(base_anchor) && return nothing
  base_anchor - mark_anchor
end

struct MarkToLigatureRule
  mark_coverage::Coverage
  ligature_coverage::Coverage
  ligature_attaches::Vector{Vector{Vector{Optional{AnchorPoint}}}} # indexed by ligature coverage index, then by ligature component and then by 0-based mark class
  mark_anchors::Vector{MarkAnchor} # indexed by mark coverage index
end

function apply_positioning_rule((mark, ligature)::Pair{GlyphID}, rule::MarkToLigatureRule, ligature_component)
  i = match(rule.mark_coverage, mark)
  isnothing(i) && return nothing
  j = match(rule.ligature_coverage, ligature)
  isnothing(j) && return nothing
  mark_anchor = rule.mark_anchors[i]
  base_anchor = rule.base_anchor_indices[j][ligature_component][mark_anchor.class + 1]
  isnothing(base_anchor) && return nothing
  base_anchor - mark_anchor
end

struct MarkToMarkRule
  mark_coverage::Coverage
  base_mark_coverage::Coverage
  base_mark_anchors::Vector{Vector{Optional{AnchorPoint}}} # indexed by base mark coverage index and then by 0-based mark class
  mark_anchors::Vector{MarkAnchor} # indexed by mark coverage index
end

function apply_positioning_rule((mark, base_mark)::Pair{GlyphID}, rule::MarkToMarkRule)
  i = match(rule.mark_coverage, mark)
  isnothing(i) && return nothing
  j = match(rule.base_mark_coverage, base_mark)
  isnothing(j) && return nothing
  mark_anchor = rule.mark_anchors[i]
  base_anchor = rule.base_mark_anchors[j][mark_anchor.class + 1]
  isnothing(base_anchor) && return nothing
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

function ClassPairAdjustmentPositioning(table::PairAdjustmentTableFormat2)
  class_first = ClassDefinition(table.class_def_1_table)
  class_second = ClassDefinition(table.class_def_2_table)
  pairs = [[GlyphOffset(pair.value_record_1) => GlyphOffset(pair.value_record_2) for pair in record] for record in table.class_1_records]
  ClassPairAdjustmentPositioning(table.coverage_table, class_first, class_second, pairs)
end

function GlyphOffset(value::ValueRecord)
  origin = Point{2,Int16}(something(value.x_placement, 0), something(value.y_placement, 0))
  advance = Point{2,Int16}(something(value.x_advance, 0), something(value.y_advance, 0))
  GlyphOffset(origin, advance)
end

AnchorPoint(table::AnchorTable) = Point(table.x_coordinate, table.y_coordinate)

function CursivePositioningRule(table::GPOSLookupCursiveAttachmentTable)
  entry_exits = [AnchorPoint(record.entry_anchor_table) => AnchorPoint(record.exit_anchor_table) for record in table.entry_exit_records]
  CursivePositioningRule(table.coverage_table, entry_exits)
end

function MarkToBaseRule(table::GPOSLookupMarkToBaseAttachmentTable)
  base_anchors = [[isnothing(anchor) ? nothing : AnchorPoint(anchor) for anchor in record] for record.base_anchor_tables in table.base_array_table.base_records]
  mark_anchors = [MarkAnchor(record.mark_class, AnchorPoint(record.mark_anchor_table)) for record in table.mark_array_table.mark_records]
  MarkToBaseRule(table.mark_coverage_table, table.base_coverage_table, base_anchors, mark_anchors)
end

function MarkToLigatureRule(table::GPOSLookupMarkToLigatureAttachmentTable)
  (; ligature_attach_tables) = table.ligature_array_table
  ligature_attaches = [[[isnothing(anchor) ? nothing : AnchorPoint(anchor) for anchor in record.ligature_anchor_tables] for record in table.component_records] for table in ligature_attach_tables]
  mark_anchors = [MarkAnchor(record.mark_class, AnchorPoint(record.mark_anchor_table)) for record in table.mark_array_table.mark_records]
  MarkToLigatureRule(table.mark_coverage_table, table.ligature_coverage_table, ligature_attaches, mark_anchors)
end

function MarkToMarkRule(table::GPOSLookupMarkToMarkAttachmentTable)
  base_mark_anchors = [[isnothing(anchor) ? nothing : AnchorPoint(anchor) for anchor in record.mark_2_anchor_tables] for record in table.mark_2_array_table.mark_records]
  mark_anchors = [MarkAnchor(record.mark_class, AnchorPoint(record.mark_anchor_table)) for record in table.mark_1_array_table.mark_records]
  MarkToLigatureRule(table.mark_1_coverage_table, table.mark_2_coverage_table, base_mark_anchors, mark_anchors)
end

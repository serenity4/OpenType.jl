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

const PositioningRule = FeatureRule{PositioningRuleType}

struct GlyphPositioning <: LookupFeatureSet
  scripts::Dict{Tag4,Script}
  features::Vector{Feature}
  rules::Vector{PositioningRule}
end

struct GlyphOffset
  "Offset to the origin of the glyph."
  origin::Vec{2,Int16}
  "Offset to the advance that will be applied to the pen position after writing the glyph to proceed to the next one."
  advance::Vec{2,Int16}
end

GlyphOffset(x_offset, y_offset, x_advance, y_advance) = GlyphOffset(Vec{2,Int16}(x_offset, y_offset), Vec{2,Int16}(x_advance, y_advance))

Base.show(io::IO, offset::GlyphOffset) = print(io, GlyphOffset, "(origin = ", offset.origin, ", advance = ", offset.advance, ")")

Base.zero(::Type{GlyphOffset}) = GlyphOffset(zero(Vec{2,Int16}), zero(Vec{2,Int16}))
Base.:(+)(x::GlyphOffset, y::GlyphOffset) = GlyphOffset(x.origin + y.origin, x.advance + y.advance)

apply_positioning_rules!(glyph_offsets::AbstractVector{GlyphOffset}, gpos::GlyphPositioning, gdef::Optional{GlyphDefinition}, glyphs::AbstractVector{GlyphID}, script_tag::Tag4, language_tag::Tag4, enabled_features::Set{Tag4}, disabled_features::Set{Tag4}, direction::Direction, callback::Optional{Function}) = apply_positioning_rules!(glyph_offsets, gpos, gdef, glyphs, applicable_features(gpos, script_tag, language_tag, enabled_features, disabled_features, direction), callback)

function apply_positioning_rules!(glyph_offsets::AbstractVector{GlyphOffset}, gpos::GlyphPositioning, gdef::Optional{GlyphDefinition}, glyphs::AbstractVector{GlyphID}, features::Vector{Feature}, callback::Optional{Function})
  for feature in features
    for rule in applicable_rules(gpos, feature)
      i = firstindex(glyphs)
      while i ≤ lastindex(glyphs)
        next = apply_positioning_rule!(glyph_offsets, rule, gpos, gdef, i, glyphs, nothing, feature, callback)
        i = something(next, i + 1)
      end
    end
  end
  glyph_offsets
end

function apply_positioning_rule!(glyph_offsets::AbstractVector{GlyphOffset}, rule::PositioningRule, gpos::GlyphPositioning, gdef::Optional{GlyphDefinition}, i::Int, glyphs::AbstractVector{GlyphID}, ligature_component::Optional{Int}, feature::Feature, callback::Optional{Function})
  !isnothing(gdef) && should_skip(rule, glyphs[i], gdef) && return nothing
  (; type, rule_impls) = rule
  if type == POSITIONING_RULE_ADJUSTMENT
    for impl::AdjustmentPositioning in rule_impls
      offset = apply_positioning_rule(glyphs[i], impl)
      if !isnothing(offset)
        !isnothing(callback) && callback(rule, feature, glyphs, i, offset, i:i)
        glyph_offsets[i] += offset
        return i + 1
      end
    end
  elseif type == POSITIONING_RULE_PAIR_ADJUSTMENT && i < lastindex(glyphs)
    for impl::Union{PairAdjustmentPositioning, ClassPairAdjustmentPositioning} in rule_impls
      ret = apply_positioning_rule(glyphs[i] => glyphs[i + 1], impl)
      if !isnothing(ret)
        !isnothing(callback) && callback(rule, feature, glyphs, i, collect(ret), i:(i + 1))
        glyph_offsets[i] += ret.first
        glyph_offsets[i + 1] += ret.second
        return ret.second == zero(GlyphOffset) ? i + 1 : i + 2
      end
    end
  elseif in(type, (POSITIONING_RULE_CURSIVE, POSITIONING_RULE_MARK_TO_BASE, POSITIONING_RULE_MARK_TO_LIGATURE, POSITIONING_RULE_MARK_TO_MARK)) && i > firstindex(glyphs)
    if type == POSITIONING_RULE_MARK_TO_LIGATURE
      for impl::MarkToLigatureRule in rule_impls
        ret = apply_positioning_rule(glyphs[i - 1] => glyphs[i], impl, ligature_component::Int)
        if !isnothing(ret)
          offset = align_anchors(glyph_offsets, i, ret)
          !isnothing(callback) && callback(rule, feature, glyphs, i, offset, i:i)
          glyph_offsets[i] += offset
          return i + 1
        end
      end
    else
      for impl::Union{CursivePositioningRule, MarkToBaseRule, MarkToMarkRule} in rule_impls
        ret = apply_positioning_rule(glyphs[i - 1] => glyphs[i], impl)
        if !isnothing(ret)
          offset = align_anchors(glyph_offsets, i, ret)
          glyph_offsets[i] += offset
          !isnothing(callback) && callback(rule, feature, glyphs, i, offset, i:i)
          return i + 1
        end
      end
    end
  elseif type == POSITIONING_RULE_CONTEXTUAL
    for impl::ContextualRule in rule_impls
      last_matched = contextual_match(i, glyphs, impl) do rules
        !isnothing(callback) && callback(rule, feature, glyphs, i, rules, i:(i + length(rules) - 1))
        apply_positioning_rules_recursive!(glyph_offsets, i, gpos, gdef, glyphs, ligature_component, rules, callback)
      end
      !isnothing(last_matched) && return last_matched + 1
    end
  elseif type == POSITIONING_RULE_CONTEXTUAL_CHAINED
    for impl::ChainedContextualRule in rule_impls
      last_matched = chained_contextual_match(i, glyphs, impl) do rules
        !isnothing(callback) && callback(rule, feature, glyphs, i, rules, i:(i + length(rules) - 1))
        apply_positioning_rules_recursive!(glyph_offsets, i, gpos, gdef, glyphs, ligature_component, rules, callback)
      end
      !isnothing(last_matched) && return last_matched + 1
    end
  end
end

function apply_positioning_rules_recursive!(glyph_offsets, i, gpos, gdef, glyphs, ligature_component, rules, callback)
  jmax = 0
  for (seq_index, lookup_index) in rules
    j = i + (seq_index - 1)
    jmax = max(jmax, j)
    apply_positioning_rule!(glyph_offsets, gpos.rules[lookup_index], gpos, gdef, glyphs, ligature_component, j, callback)
  end
  jmax
end

function align_anchors(offsets::AbstractVector{GlyphOffset}, i::Int, (base, next)::Tuple{Vec{2,Int16}, Vec{2,Int16}})
  base_origin = offsets[i - 1].origin
  advance = offsets[i - 1].advance
  next_origin = offsets[i].origin

  # Anchors are expressed in the design space.
  # We first compute the offset vector between these two points, then
  # adjust it taking into consideration the current offset between
  # the base and next glyphs. Once the current offset has been
  # computed, all that is needed is to add the offsets together.
  alignment_offset = next - base
  position_offset = (next_origin + advance) - base_origin
  offset = alignment_offset + position_offset
  origin = -offset
  GlyphOffset(origin, zero(Vec{2,Int16}))
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
  contains(pattern.coverage, first) && return get(pattern.pairs, second, nothing)
  nothing
end

struct ClassPairAdjustmentPositioning
  coverage::Coverage
  class_first::ClassDefinition
  class_second::ClassDefinition
  pairs::Vector{Vector{Pair{GlyphOffset, GlyphOffset}}} # by 0-based index into first then second class definition
end

function apply_positioning_rule((first, second)::Pair{GlyphID}, pattern::ClassPairAdjustmentPositioning)
  !contains(pattern.coverage, first) && return nothing
  c1 = class(first, pattern.class_first)
  c2 = class(second, pattern.class_second)
  pattern.pairs[c1 + 1][c2 + 1]
end

const AnchorPoint = Vec{2,Int16}

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
  current_exit, next_entry
end

struct MarkToBaseRule
  mark_coverage::Coverage
  base_coverage::Coverage
  base_anchor_indices::Vector{Vector{Optional{AnchorPoint}}} # indexed by base coverage index and then by 0-based mark class
  mark_anchors::Vector{MarkAnchor} # indexed by mark coverage index
end

function apply_positioning_rule((base, mark)::Pair{GlyphID}, rule::MarkToBaseRule)
  i = match(rule.base_coverage, base)
  isnothing(i) && return nothing
  j = match(rule.mark_coverage, mark)
  isnothing(j) && return nothing
  mark_anchor = rule.mark_anchors[j]
  base_anchor = rule.base_anchor_indices[i][mark_anchor.class + 1]
  isnothing(base_anchor) && return nothing
  base_anchor, mark_anchor.anchor
end

struct MarkToLigatureRule
  mark_coverage::Coverage
  ligature_coverage::Coverage
  ligature_attaches::Vector{Vector{Vector{Optional{AnchorPoint}}}} # indexed by ligature coverage index, then by ligature component and then by 0-based mark class
  mark_anchors::Vector{MarkAnchor} # indexed by mark coverage index
end

function apply_positioning_rule((ligature, mark)::Pair{GlyphID}, rule::MarkToLigatureRule, ligature_component::Optional{Int})
  i = match(rule.ligature_coverage, ligature)
  isnothing(i) && return nothing
  j = match(rule.mark_coverage, mark)
  isnothing(j) && return nothing
  mark_anchor = rule.mark_anchors[j]
  base_anchor = rule.base_anchor_indices[i][ligature_component][mark_anchor.class + 1]
  isnothing(base_anchor) && return nothing
  base_anchor, mark_anchor.anchor
end

struct MarkToMarkRule
  mark_coverage::Coverage
  base_mark_coverage::Coverage
  base_mark_anchors::Vector{Vector{Optional{AnchorPoint}}} # indexed by base mark coverage index and then by 0-based mark class
  mark_anchors::Vector{MarkAnchor} # indexed by mark coverage index
end

function apply_positioning_rule((base_mark, mark)::Pair{GlyphID}, rule::MarkToMarkRule)
  i = match(rule.base_mark_coverage, base_mark)
  isnothing(i) && return nothing
  j = match(rule.mark_coverage, mark)
  isnothing(j) && return nothing
  mark_anchor = rule.mark_anchors[j]
  base_anchor = rule.base_mark_anchors[j][mark_anchor.class + 1]
  isnothing(base_anchor) && return nothing
  base_anchor, mark_anchor.anchor
end

# -----------------------------------
# Conversions from serializable types

AdjustmentPositioning(table::SingleAdjustmentTableFormat1) = AdjustmentPositioning(Coverage(table.coverage_table), GlyphOffset(table.value_record))
AdjustmentPositioning(table::SingleAdjustmentTableFormat2) = AdjustmentPositioning(Coverage(table.coverage_table), GlyphOffset.(table.value_records))

function PairAdjustmentPositioning(table::PairAdjustmentTableFormat1)
  pairs = Dict{GlyphID, Pair{GlyphOffset, GlyphOffset}}()
  for set in table.pair_set_tables
    for pair in set.pair_value_record
      pairs[pair.second_glyph] = GlyphOffset(pair.value_record_1) => GlyphOffset(pair.value_record_2)
    end
  end
  PairAdjustmentPositioning(Coverage(table.coverage_table), pairs)
end

function ClassPairAdjustmentPositioning(table::PairAdjustmentTableFormat2)
  class_first = ClassDefinition(table.class_def_1_table)
  class_second = ClassDefinition(table.class_def_2_table)
  pairs = [[GlyphOffset(pair.value_record_1) => GlyphOffset(pair.value_record_2) for pair in record] for record in table.class_1_records]
  ClassPairAdjustmentPositioning(Coverage(table.coverage_table), class_first, class_second, pairs)
end

pair_adjustment_positioning(table::PairAdjustmentTableFormat1) = PairAdjustmentPositioning(table)
pair_adjustment_positioning(table::PairAdjustmentTableFormat2) = ClassPairAdjustmentPositioning(table)

function GlyphOffset(value::ValueRecord)
  origin = Vec{2,Int16}(something(value.x_placement, 0), something(value.y_placement, 0))
  advance = Vec{2,Int16}(something(value.x_advance, 0), something(value.y_advance, 0))
  GlyphOffset(origin, advance)
end

AnchorPoint(table::AnchorTable) = Vec(table.x_coordinate, table.y_coordinate)
anchor_point(::Nothing) = nothing
anchor_point(table::AnchorTable) = AnchorPoint(table)

function CursivePositioningRule(table::GPOSLookupCursiveAttachmentTable)
  entry_exits = [anchor_point(record.entry_anchor_table) => anchor_point(record.exit_anchor_table) for record in table.entry_exit_records]
  CursivePositioningRule(Coverage(table.coverage_table), entry_exits)
end

function MarkToBaseRule(table::GPOSLookupMarkToBaseAttachmentTable)
  base_anchors = [anchor_point.(record.base_anchor_tables) for record in table.base_array_table.base_records]
  mark_anchors = [MarkAnchor(record.mark_class, AnchorPoint(record.mark_anchor_table)) for record in table.mark_array_table.mark_records]
  MarkToBaseRule(Coverage(table.mark_coverage_table), Coverage(table.base_coverage_table), base_anchors, mark_anchors)
end

function MarkToLigatureRule(table::GPOSLookupMarkToLigatureAttachmentTable)
  (; ligature_attach_tables) = table.ligature_array_table
  ligature_attaches = [[anchor_point.(record.ligature_anchor_tables) for record in table.component_records] for table in ligature_attach_tables]
  mark_anchors = [MarkAnchor(record.mark_class, AnchorPoint(record.mark_anchor_table)) for record in table.mark_array_table.mark_records]
  MarkToLigatureRule(Coverage(table.mark_coverage_table), Coverage(table.ligature_coverage_table), ligature_attaches, mark_anchors)
end

function MarkToMarkRule(table::GPOSLookupMarkToMarkAttachmentTable)
  base_mark_anchors = [anchor_point.(record.mark_2_anchor_tables) for record in table.mark_2_array_table.mark_records]
  mark_anchors = [MarkAnchor(record.mark_class, AnchorPoint(record.mark_anchor_table)) for record in table.mark_1_array_table.mark_records]
  MarkToMarkRule(Coverage(table.mark_1_coverage_table), Coverage(table.mark_2_coverage_table), base_mark_anchors, mark_anchors)
end

function PositioningRule(table::GPOSLookupTable)
  (; lookup_type, subtables) = table
  rule_impls = if lookup_type == 1
    Any[AdjustmentPositioning(table) for table::Union{SingleAdjustmentTableFormat1, SingleAdjustmentTableFormat2} in subtables]
  elseif lookup_type == 2
    Any[pair_adjustment_positioning(table) for table::Union{PairAdjustmentTableFormat1, PairAdjustmentTableFormat2} in subtables]
  elseif lookup_type == 3
    Any[CursivePositioningRule(table) for table::GPOSLookupCursiveAttachmentTable in subtables]
  elseif lookup_type == 4
    Any[MarkToBaseRule(table) for table::GPOSLookupMarkToBaseAttachmentTable in subtables]
  elseif lookup_type == 5
    Any[MarkToLigatureRule(table) for table::GPOSLookupMarkToLigatureAttachmentTable in subtables]
  elseif lookup_type == 6
    Any[MarkToMarkRule(table) for table::GPOSLookupMarkToMarkAttachmentTable in subtables]
  elseif lookup_type == 7
    Any[ContextualRule(table.table::Union{SequenceContextTableFormat1, SequenceContextTableFormat2, SequenceContextTableFormat3}) for table::GPOSContextualTable in subtables]
  elseif lookup_type == 8
    Any[ChainedContextualRule(table.table::Union{ChainedSequenceContextFormat1, ChainedSequenceContextFormat2, ChainedSequenceContextFormat3}) for table::GPOSChainedContextualTable in subtables]
  else
    @assert false
  end
  PositioningRule(PositioningRuleType(lookup_type), table.lookup_flag, table.mark_filtering_set, rule_impls)
end

function positioning_rules(table::GlyphPositioningTable)
  rules = PositioningRule[]
  for lookup_table::GPOSLookupTable in table.lookup_list_table.lookup_tables
    if lookup_table.lookup_type == 9
      (; subtables) = lookup_table
      (; extension_lookup_type) = subtables[1]
      lookup_table = setproperties(lookup_table, (; lookup_type = extension_lookup_type, subtables = [table.extension_table for table in subtables]))
    end
    push!(rules, PositioningRule(lookup_table))
  end
  rules
end

function GlyphPositioning(gpos::GlyphPositioningTable)
  scripts = Dict(script.tag => script for script in Script.(gpos.script_list_table.script_records))
  features = Feature.(gpos.feature_list_table.feature_records)
  GlyphPositioning(scripts, features, positioning_rules(gpos))
end

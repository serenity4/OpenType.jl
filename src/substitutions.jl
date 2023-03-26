@enum SubstitutionRuleType::UInt8 begin
  SUBSTITUTION_RULE_SINGLE = 1
  SUBSTITUTION_RULE_MULTIPLE = 2
  SUBSTITUTION_RULE_ALTERNATE = 3
  SUBSTITUTION_RULE_LIGATURE = 4
  SUBSTITUTION_RULE_CONTEXTUAL = 5
  SUBSTITUTION_RULE_CONTEXTUAL_CHAINED = 6
  SUBSTITUTION_RULE_REVERSE_CONTEXTUAL_CHAINED_SINGLE = 7
end

const SubstitutionRule = FeatureRule{SubstitutionRuleType}

struct GlyphSubstitution <: LookupFeatureSet
  scripts::Dict{Tag{4},Script}
  features::Vector{Feature}
  rules::Vector{SubstitutionRule}
end

apply_substitution_rules!(glyphs::AbstractVector{GlyphID}, gsub::GlyphSubstitution, gdef::Optional{GlyphDefinition}, script_tag::Tag{4}, language_tag::Tag{4}, enabled_features::Set{Tag{4}}, disabled_features::Set{Tag{4}}, direction::Direction, choose_alternate::Function, callback::Optional{Function}) = apply_substitution_rules!(glyphs, gsub, gdef, applicable_features(gsub, script_tag, language_tag, enabled_features, disabled_features, direction), choose_alternate, callback)

function apply_substitution_rules!(glyphs::AbstractVector{GlyphID}, gsub::GlyphSubstitution, gdef::Optional{GlyphDefinition}, features::Vector{Feature}, choose_alternate::Function, callback::Optional{Function})
  for feature in features
    for rule in applicable_rules(gsub, feature)
      i = firstindex(glyphs)
      while i ≤ lastindex(glyphs)
        next = apply_substitution_rule!(glyphs, rule, gsub, gdef, i, choose_alternate, feature, callback)
        i = something(next, i + 1)
      end
    end
  end
  glyphs
end

function apply_substitution_rule!(glyphs::AbstractVector{GlyphID}, rule::SubstitutionRule, gsub::GlyphSubstitution, gdef::Optional{GlyphDefinition}, i::Int, choose_alternate::Function, feature::Feature, callback::Optional{Function})
  !isnothing(gdef) && should_skip(rule, glyphs[i], gdef) && return nothing
  (; type, rule_impls) = rule
  if type == SUBSTITUTION_RULE_SINGLE
    for impl::SingleSubstitution in rule_impls
      sub = apply_substitution_rule(glyphs[i], impl)
      if !isnothing(sub)
        !isnothing(callback) && callback(rule, feature, glyphs, i, sub, i:i)
        glyphs[i] = sub
        return i + 1
      end
    end
  elseif type == SUBSTITUTION_RULE_MULTIPLE
    for impl::MultipleSubtitution in rule_impls
      ret = apply_substitution_rule(glyphs[i], impl)
      if !isnothing(ret)
        !isnothing(callback) && callback(rule, feature, glyphs, i, ret, i:i)
        sub, subs... = ret
        glyphs[i] = sub
        for sub in subs
          insert!(glyphs, i + 1, sub)
        end
        return i + 1 + length(subs)
      end
    end
  elseif type == SUBSTITUTION_RULE_ALTERNATE
    for impl::AlternateSubtitution in rule_impls
      alts = alternatives(glyphs[i], impl)
      if !isnothing(alts)
        alt = choose_alternate(glyphs[i], alts)
        !isnothing(callback) && callback(rule, feature, glyphs, i, alt, i:i)
        glyphs[i] = alt
        return i + 1
      end
    end
  elseif type == SUBSTITUTION_RULE_LIGATURE && i < lastindex(glyphs)
    for impl::LigatureSubstitution in rule_impls
      ret = apply_substitution_rule(glyphs, i, impl)
      if !isnothing(ret)
        n, sub = ret
        !isnothing(callback) && callback(rule, feature, glyphs, i, sub, i:(i + n - 1))
        glyphs[i] = sub
        splice!(glyphs, (i + 1):(i + n - 1))
        return i + n
      end
    end
  elseif type == SUBSTITUTION_RULE_CONTEXTUAL
    for impl::ContextualRule in rule_impls
      last_matched = contextual_match(i, glyphs, impl) do rules
        !isnothing(callback) && callback(rule, feature, glyphs, i, rules, i:i)
        apply_substitution_rules_recursive!(glyphs, i, gsub, gdef, callback)
      end
      !isnothing(last_matched) && return last_matched + 1
    end
  elseif type == SUBSTITUTION_RULE_CONTEXTUAL_CHAINED
    for impl::ChainedContextualRule in rule_impls
      last_matched = chained_contextual_match(i, glyphs, impl) do rules
        !isnothing(callback) && callback(rule, feature, glyphs, i, rules, i:i)
        apply_substitution_rules_recursive!(glyphs, i, gsub, gdef, callback)
      end
      !isnothing(last_matched) && return last_matched + 1
    end
  elseif type == SUBSTITUTION_RULE_REVERSE_CONTEXTUAL_CHAINED_SINGLE
    # TODO
  end
end

function apply_substitution_rules_recursive!(glyphs, i, gsub, gdef, rules, callback)
  jmax = 0
  for (seq_index, lookup_index) in rules
    j = i + (seq_index - 1)
    jmax = max(jmax, j)
    apply_substitution_rule!(glyphs, gsub.rules[lookup_index], gsub, gdef, j, callback)
  end
  jmax
end

struct SingleSubstitution
  coverage::Coverage
  substitution::Union{GlyphIDOffset, Vector{GlyphID}}
end

struct MultipleSubtitution
  coverage::Coverage
  substitutions::Vector{Vector{GlyphID}}
end

struct AlternateSubtitution
  coverage::Coverage
  alternatives::Vector{Vector{GlyphID}}
end

struct LigatureEntry
  "Tail glyphs which must be matched to apply the substitution."
  tail_match::Vector{GlyphID}
  "Glyph to be substituted."
  substitution::GlyphID
end

struct LigatureSubstitution
  coverage::Coverage
  ligatures::Vector{Vector{LigatureEntry}} # first array indexed by coverage index
end

function apply_substitution_rule(glyph::GlyphID, pattern::SingleSubstitution)
  i = match(pattern.coverage, glyph)
  !isnothing(i) && return isa(pattern.substitution, GlyphID) ? glyph + pattern.substitution : pattern.substitution[i]
  nothing
end

function apply_substitution_rule(glyph::GlyphID, pattern::MultipleSubtitution)
  i = match(pattern.coverage, glyph)
  !isnothing(i) && return pattern.substitutions[i]
  nothing
end

function alternatives(glyph::GlyphID, pattern::AlternateSubtitution)
  i = match(pattern.coverage, glyph)
  !isnothing(i) && return pattern.alternatives[i]
  nothing
end

function apply_substitution_rule(glyphs::Vector{GlyphID}, i::Integer, pattern::LigatureSubstitution)
  j = match(pattern.coverage, glyphs[i])
  !isnothing(j) && for ligature in pattern.ligatures[j]
      n = length(ligature.tail_match)
      ligature.tail_match == (@view glyphs[(i + 1):(n - 1)]) && return (n + 1, ligature.substitution)
    end
  nothing
end

function apply_substitution_rule(glyphs::Vector{GlyphID}, pattern::ContextualRule, lookups)
  contextual_match(glyphs, pattern) do glyphs, sequence
    res = copy(glyphs)
    (; rules) = sequence
    unmatched = Set(eachindex(glyphs))
    for (index, lookup_index) in rules
      in(index, unmatched) || continue
      new = f(glyphs[index], lookups[lookup_index])
      if !isnothing(new)
        res[index] = new
        delete!(unmatched, index)
        isempty(unmatched) && break
      end
    end
    res
  end
end

# -----------------------------------
# Conversions from serializable types

SingleSubstitution(table::SingleTableFormat1) = SingleSubstitution(Coverage(table.coverage_table), table.delta_glyph_id)
SingleSubstitution(table::SingleTableFormat2) = SingleSubstitution(Coverage(table.coverage_table), table.substitute_glyph_ids)
MultipleSubtitution(table::GSUBLookupMultipleTable) = MultipleSubtitution(Coverage(table.coverage_table), [seq.substitute_glyph_ids for seq in table.sequence_tables])
AlternateSubtitution(table::GSUBLookupAlternateTable) = AlternateSubtitution(Coverage(table.coverage_table), [set.alternate_glyph_ids for set in table.alternate_set_tables])

LigatureEntry(table::LigatureTable) = LigatureEntry(table.component_glyph_ids, table.ligature_glyph)
LigatureSubstitution(table::GSUBLookupLigatureTable) = LigatureSubstitution(Coverage(table.coverage_table), [LigatureEntry.(set.ligature_tables) for set in table.ligature_set_tables])

function SubstitutionRule(table::GSUBLookupTable)
  (; lookup_type, subtables) = table
  rule_impls = if lookup_type == 1
    Any[SingleSubstitution(table) for table::Union{SingleTableFormat1, SingleTableFormat2} in subtables]
  elseif lookup_type == 2
    Any[MultipleSubtitution(table) for table::GSUBLookupMultipleTable in subtables]
  elseif lookup_type == 3
    Any[AlternateSubtitution(table) for table::GSUBLookupAlternateTable in subtables]
  elseif lookup_type == 4
    Any[LigatureSubstitution(table) for table::GSUBLookupLigatureTable in subtables]
  elseif lookup_type == 5
    Any[ContextualRule(table.table::Union{SequenceContextTableFormat1, SequenceContextTableFormat2, SequenceContextTableFormat3}) for table::GSUBContextualTable in subtables]
  elseif lookup_type == 6
    Any[ChainedContextualRule(table.table::Union{ChainedSequenceContextFormat1, ChainedSequenceContextFormat2, ChainedSequenceContextFormat3}) for table::GSUBChainedContextualTable in subtables]
  else
    @assert false
  end
  # We don't cover the extension table, and there are tables after it.
  lookup_type > 7 && (lookup_type -= 1)
  SubstitutionRule(SubstitutionRuleType(lookup_type), table.lookup_flag, table.mark_filtering_set, rule_impls)
end

# There is quite some overlap with the GlyphPositioning table, we might want to factor out the common logic.

function substitution_rules(table::GlyphSubstitutionTable)
  rules = SubstitutionRule[]
  for lookup_table::GSUBLookupTable in table.lookup_list_table.lookup_tables
    if lookup_table.lookup_type == 7
      (; subtables) = lookup_table
      (; extension_lookup_type) = subtables[1]
      lookup_table = setproperties(lookup_table, (; lookup_type = extension_lookup_type, subtables = [table.extension_table for table in subtables]))
    end
    push!(rules, SubstitutionRule(lookup_table))
  end
  rules
end

function GlyphSubstitution(gpos::GlyphSubstitutionTable)
  scripts = Dict(script.tag => script for script in Script.(gpos.script_list_table.script_records))
  features = Feature.(gpos.feature_list_table.feature_records)
  GlyphSubstitution(scripts, features, substitution_rules(gpos))
end

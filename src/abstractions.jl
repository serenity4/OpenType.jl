struct Feature
  tag::Tag{4}
  lookup_indices::Vector{UInt16}
end

struct LanguageSystem
  tag::Tag{4}
  required_feature_index::UInt16
  feature_indices::Vector{UInt16}
end

struct Script
  tag::Tag{4}
  languages::Vector{LanguageSystem}
  default_language::Optional{LanguageSystem}
end

function language_system(script_tag::Tag{4}, language_tag::Tag{4}, scripts::Dict{Tag{4},Script})
  script = get(scripts, script_tag, nothing)
  isnothing(script) && error("Script '$script_tag' not found.")
  language_idx = findfirst(x -> x.tag == language_tag, script.languages)
  !isnothing(language_idx) && return script.languages[language_idx]
  !isnothing(script.default_language) && return script.default_language
  if language_tag ≠ tag"DFLT"
      language_idx = findfirst(x -> x.tag == tag"DFLT", script.languages)
      !isnothing(language_idx) && return script.languages[language_idx]
  end
  nothing
end

"""
Glyph-matching coverage structure.

Matching can be done either by individual glyphs or by glyph ranges.
"""
struct Coverage
  ranges::Vector{UnitRange{GlyphID}}
  glyphs::Vector{GlyphID}
end

"""
Return a 1-based coverage index if the given glyph ID is included in the coverage structure.
"""
function Base.match(coverage::Coverage, glyph::GlyphID)
  for (i, g) in enumerate(coverage.glyphs)
    g == glyph && return i
  end
  i = 0
  for range in coverage.ranges
    j = findfirst(==(glyph), range)
    !isnothing(j) && return i + j
    i += length(range)
  end
  nothing
end

Base.contains(coverage::Coverage, glyph::GlyphID) = !isnothing(match(coverage, glyph))

struct RangeClass
  "Range of glyphs by ID which are mapped to this class."
  range::UnitRange{GlyphID}
  "Class which all glyphs in the range are defined to be part of."
  class::ClassID
end

struct ClassDefinition
  "Classes by glyph range."
  by_range::Vector{RangeClass}
  "Classes by glyph. Glyphs are identified as `i - 1 + start_glyph_id`."
  by_glyph::Vector{ClassID}
  start_glyph_id::GlyphID
end

function class(glyph::GlyphID, def::ClassDefinition)
  # There should not be any overlap within the same `ClassDefinition`;
  # all glyphs will be assigned a single class or none (class 0 implicitly).
  in(glyph, def.start_glyph_id:(def.start_glyph_id + length(def.by_glyph) - 1)) && return def.by_glyph[1 + (glyph - def.start_glyph_id)]
  for rc in def.by_range
    in(glyph, rc.range) && return rc.class
  end
  zero(ClassID)
end

struct SequenceEntry{T<:Union{GlyphID, ClassID, Coverage}}
  tail::Vector{T}
  rules::Vector{Pair{UInt16,UInt16}} # sequence index => rule index
end

struct ContextualRule
  coverage::Optional{Coverage}
  glyph_sequences::Optional{Vector{Optional{Vector{SequenceEntry{GlyphID}}}}} # coverage index => sequence index
  class_sequences::Optional{Vector{Optional{Vector{SequenceEntry{ClassID}}}}} # coverage index => sequence index
  class_definition::Optional{ClassDefinition}
  coverage_sequence::Optional{SequenceEntry{Coverage}}
end

function is_glyph_match(f, glyphs, i, sequence, k, offset = 0)
  j = i + offset + k - 1
  in(eachindex(glyphs), j) || return false
  f(sequence[k], glyphs[j])
end

function contextual_match(f, i, glyphs, rule::ContextualRule)
  (; coverage, glyph_sequences, class_sequences, class_definition, coverage_sequence) = rule
  if !isnothing(coverage)
    j = match(coverage, glyphs[i])
    isnothing(j) && return nothing
    if !isnothing(glyph_sequences)
      sequences = glyph_sequences[j]
      isnothing(sequences) && return nothing
      for sequence in sequences
        all(is_glyph_match((==), glyphs, i, sequence.tail, k) for k in eachindex(sequence.tail)) && return f(sequence.rules)
      end
    elseif !isnothing(class_sequences)
      sequences = class_sequences[j]
      isnothing(sequences) && return nothing
      class_definition::ClassDefinition
      for sequence in sequences
        all(is_glyph_match((x, glyph) -> x == class(glyph, class_definition), glyphs, i, sequence.tail, k) for k in eachindex(sequence.tail)) && return f(sequence.rules)
      end
    end
  else
    sequence = coverage_sequence::SequenceEntry{Coverage}
    all(is_glyph_match(contains, glyphs, i, sequence.tail, k) for k in eachindex(sequence.tail)) && return f(sequence.rules)
  end
  nothing
end

struct ChainedSequenceEntry{T<:Union{GlyphID, ClassID, Coverage}}
  backtrack::Vector{T}
  tail::Vector{T}
  lookahead::Vector{T}
  rules::Vector{Pair{UInt16,UInt16}} # sequence index => rule index
end

struct ChainedContextualRule
  coverage::Optional{Coverage}
  glyph_sequences::Optional{Vector{Optional{Vector{ChainedSequenceEntry{GlyphID}}}}}
  class_sequences::Optional{Vector{Optional{Vector{ChainedSequenceEntry{ClassID}}}}}
  class_definitions::Optional{NTuple{3, ClassDefinition}} # backtrack, input and lookahead classes
  coverage_sequence::Optional{ChainedSequenceEntry{Coverage}}
end

function chained_contextual_match(f, i, glyphs, rule::ChainedContextualRule)
  (; coverage, glyph_sequences, class_sequences, class_definitions, coverage_sequence) = rule
  if !isnothing(coverage)
    j = match(coverage, glyphs[i])
    isnothing(j) && return nothing
    if !isnothing(glyph_sequences)
      sequences = glyph_sequences[j]
      isnothing(sequences) && return nothing
      for sequence in sequences
        all(is_glyph_match((==), glyphs, i, sequence.tail, k) for k in eachindex(sequence.tail)) &&
          all(is_glyph_match((==), glyphs, i, sequence.lookahead, k, -length(sequence.lookahead)) for k in eachindex(sequence.lookahead)) &&
          all(is_glyph_match((==), glyphs, i, sequence.backtrack, k, length(sequence.backtrack)) for k in eachindex(sequence.backtrack)) &&
          return f(sequence.rules)
      end
    elseif !isnothing(class_sequences)
      sequences = class_sequences[j]
      isnothing(sequences) && return nothing
      class_definitions::NTuple{3, ClassDefinition}
      for sequence in sequences
        all(is_glyph_match((x, glyph) -> x == class(glyph, class_definitions[1]), glyphs, i, sequence.tail) for k in eachindex(sequence.tail)) &&
          all(is_glyph_match((x, glyph) -> x == class(glyph, class_definitions[2]), glyphs, i, sequence.lookahead, -length(sequence.lookahead)) for k in eachindex(sequence.lookahead)) &&
          all(is_glyph_match((x, glyph) -> x == class(glyph, class_definitions[3]), glyphs, i, sequence.backtrack, +length(sequence.tail)) for k in eachindex(sequence.backtrack)) &&
          return f(sequence.rules)
      end
    end
  else
    sequence = coverage_sequence::ChainedSequenceEntry{Coverage}
    all(is_glyph_match(contains, glyphs, i, sequence.tail, k) for k in eachindex(sequence.tail)) &&
      all(is_glyph_match(contains, glyphs, i, sequence.lookahead, k, -length(sequence.lookahead)) for k in eachindex(sequence.lookahead)) &&
      all(is_glyph_match(contains, glyphs, i, sequence.backtrack, k, length(sequence.backtrack)) for k in eachindex(sequence.backtrack)) &&
      return f(sequence.rules)
  end
  nothing
end

"Common supertype for GPOS and GSUB abstractions, which share a script- and language-based selection of features to apply."
abstract type LookupFeatureSet end

function applicable_features(fset::LookupFeatureSet, script_tag::Tag{4}, language_tag::Tag{4}, disabled_features::Set{Tag{4}})
  language = language_system(script_tag, language_tag, fset.scripts)
  isnothing(language) && return Feature[]
  features = fset.features[language.feature_indices .+ 1]
  filter!(x -> !in(x.tag, disabled_features), features)
  language.required_feature_index ≠ typemax(UInt16) && pushfirst!(features, fset.features[language.required_feature_index + 1])
  features
end

applicable_rules(fset::LookupFeatureSet, feature::Feature) = @view fset.rules[sort!(feature.lookup_indices .+ 1)]

applicable_rules(fset::LookupFeatureSet, script_tag::Tag{4}, language_tag::Tag{4}, disabled_features::Set{Tag{4}} = Set{Tag{4}}()) = applicable_rules(fset::LookupFeatureSet, applicable_features(fset, script_tag, language_tag, disabled_features))

struct FeatureRule{T}
  type::T
  flag::LookupFlag
  mark_filtering_set::Optional{UInt16}
  "Rule implementations. There can be several depending on storage efficiency."
  rule_impls::Vector{Any}
end

Base.show(io::IO, rule::FeatureRule) = print(io, typeof(rule), '(', rule.type, ", ", rule.flag, ", ", length(rule.rule_impls), " implementations)")

struct GlyphDefinition
  classes::Optional{ClassDefinition}
  # TODO: Add other fields as needed.
end

function should_skip(rule::FeatureRule, glyph::GlyphID, gdef::GlyphDefinition)
  isnothing(gdef.classes) && return false
  c = GlyphClassDef(class(glyph, gdef.classes) + 1)
  in(LOOKUP_IGNORE_BASE_GLYPHS, rule.flag) && c == GLYPH_CLASS_BASE && return true
  in(LOOKUP_IGNORE_LIGATURES, rule.flag) && c == GLYPH_CLASS_LIGATURE && return true
  in(LOOKUP_IGNORE_MARKS, rule.flag) && c == GLYPH_CLASS_MARK && return true
  false
end

# -----------------------------------
# Conversions from serializable types

function Script(record::ScriptRecord)
  table = record.script_table
  languages = LanguageSystem.(table.lang_sys_records)
  default_language = nothing
  !isnothing(table.default_lang_sys_table) && (default_language = LanguageSystem(tag"dflt", table.default_lang_sys_table.required_feature_index, table.default_lang_sys_table.feature_indices))
  Script(record.script_tag, languages, default_language)
end

function LanguageSystem(record::LangSysRecord)
  table = record.lang_sys_table
  LanguageSystem(record.lang_sys_tag, table.required_feature_index, table.feature_indices)
end

function Feature(record::FeatureRecord)
  table = record.feature_table
  Feature(record.feature_tag, table.lookup_list_indices)
end

Coverage(table::CoverageTableFormat1) = Coverage(UnitRange{GlyphID}[], table.glyph_array)
Coverage(table::CoverageTableFormat2) = Coverage([record.start_glyph_id:record.end_glyph_id for record in table.range_records], GlyphID[])

ClassDefinition(def::ClassDefinitionTableFormat1) = ClassDefinition(RangeClass[], def.class_value_array, def.start_glyph_id)
ClassDefinition(def::ClassDefinitionTableFormat2) = ClassDefinition(RangeClass.(def.class_range_records), ClassID[], 0)
RangeClass(record::ClassRangeRecord) = RangeClass(record.start_glyph_id:record.end_glyph_id, record.class)

sequence_rule(record::SequenceLookupRecord) = record.sequence_index => record.lookup_list_index
SequenceEntry(table::SequenceRuleTable) = SequenceEntry(table.input_sequence, sequence_rule.(table.seq_lookup_records))
sequence_entries(table::SequenceRuleSetTable) = SequenceEntry.(table.seq_rule_tables)
sequence_entries(::Nothing) = nothing

ContextualRule(table::SequenceContextTableFormat1) = ContextualRule(Coverage(table.coverage_table), sequence_entries.(table.seq_rule_set_tables), nothing, nothing, nothing)
ContextualRule(table::SequenceContextTableFormat2) = ContextualRule(Coverage(table.coverage_table), nothing, sequence_entries.(table.class_seq_rule_set_tables), ClassDefinition(table.class_def_table), nothing)
ContextualRule(table::SequenceContextTableFormat3) = ContextualRule(nothing, nothing, nothing, nothing, SequenceEntry(Coverage.(table.coverage_tables), sequence_rule.(table.seq_lookup_records)))

ChainedSequenceEntry(table::ChainedSequenceRuleTable) = ChainedSequenceEntry(table.backtrack_sequence, table.input_sequence, table.lookahead_sequence, sequence_rule.(table.seq_lookup_records))
chained_sequence_entries(table::ChainedSequenceRuleSetTable) = ChainedSequenceEntry.(table.chained_seq_rule_tables)
chained_sequence_entries(::Nothing) = nothing

ChainedContextualRule(table::ChainedSequenceContextFormat1) = ChainedContextualRule(Coverage(table.coverage_table), chained_sequence_entries.(table.chained_seq_rule_set_tables), nothing, nothing, nothing)
ChainedContextualRule(table::ChainedSequenceContextFormat2) = ChainedContextualRule(Coverage(table.coverage_table), nothing, chained_sequence_entries.(table.chained_class_seq_rule_set_tables), ClassDefinition.((table.backtrack_class_def_table, table.input_class_def_table, table.lookahead_class_def_table)), nothing)
ChainedContextualRule(table::ChainedSequenceContextFormat3) = ChainedContextualRule(nothing, nothing, nothing, nothing, ChainedSequenceEntry(Coverage.(table.backtrack_coverage_tables), Coverage.(table.input_coverage_tables), Coverage.(table.lookahead_coverage_tables), sequence_rule.(table.seq_lookup_records)))

GlyphDefinition(gdef::GDEFHeader_1_0) = GlyphDefinition(isnothing(gdef.glyph_class_def_table) ? nothing : ClassDefinition(gdef.glyph_class_def_table))
GlyphDefinition(gdef::GDEFHeader_1_2) = GlyphDefinition(isnothing(gdef.common.glyph_class_def_table) ? nothing : ClassDefinition(gdef.common.glyph_class_def_table))
GlyphDefinition(gdef::GDEFHeader_1_3) = GlyphDefinition(isnothing(gdef.common.common.glyph_class_def_table) ? nothing : ClassDefinition(gdef.common.common.glyph_class_def_table))

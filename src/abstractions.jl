struct Feature
  tag::Tag
  lookup_indices::Vector{UInt16}
end

struct LanguageSystem
  tag::Tag
  required_feature_index::UInt16
  feature_indices::Vector{UInt16}
end

struct Script
  tag::Tag
  languages::Vector{LanguageSystem}
  default_language::Optional{LanguageSystem}
end

function LanguageSystem(script_tag::Tag, language_tag::Tag, scripts::Dict{Tag,Script})
  script = get(scripts, script_tag, nothing)
  isnothing(script) && error("Script '$script_tag' not found.")
  language_idx = findfirst(x -> x.tag == language_tag, script.languages)
  !isnothing(language_idx) && return script.languages[language_idx]
  !isnothing(script.default_language) && return script.default_language
  if language_tag ≠ "DFLT"
      language_idx = findfirst(x -> x.tag == "DFLT", script.languages)
      !isnothing(language_idx) && return script.languages[language_idx]
  end
  error("No matching language entry found for the language '$language_tag)'")
end

"""
Glyph-matching coverage structure.

Matching can be done either by individual glyphs or by glyph ranges.
"""
struct Coverage
  ranges::Vector{UnitRange{GlyphID}}
  start_coverage_index::UInt16
  glyphs::Vector{GlyphID}
end

"""
Return a 1-based coverage index if the given glyph ID is included in the coverage structure.
"""
function Base.match(coverage::Coverage, glyph::GlyphID)
  for (i, g) in enumerate(coverage.glyphs)
    g == glyph && return i
  end
  for range in coverage.ranges
    in(glyph, range) && return 1 + glyph - coverage.start_coverage_index
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

struct SequenceEntry
  tail::Union{Vector{GlyphID}, Vector{ClassID}}
  rules::Vector{Pair{UInt16,UInt16}} # sequence index => rule index
end

struct ContextualRule
  coverage::Optional{Coverage}
  glyph_sequences::Optional{Vector{Vector{SequenceEntry}}}
  class_sequences::Optional{Vector{Vector{SequenceEntry}}}
  class_definition::Optional{ClassDefinition}
  coverage_sequences::Optional{Vector{Coverage}}
  coverage_rules::Optional{Vector{Pair{UInt16,UInt16}}} # sequence index => rule index
end

function contextual_match(f, xs, pattern)
  head, tail... = xs
  if contains(pattern.coverage, head)
    for sequence in pattern.sequences
      sequence.tail_match == tail && return f(xs, sequence)
    end
  end
end

struct ChainMatch
  backtrack_sequence::Union{Vector{GlyphID}, Vector{ClassID}}
  tail::Union{Vector{GlyphID}, Vector{ClassID}}
  lookahead_sequence::Union{Vector{GlyphID}, Vector{ClassID}}
  rules::Vector{Pair{UInt16,UInt16}} # sequence index => rule index
end

struct ChainedSequenceEntry
  matches::Vector{ChainMatch}
end

struct ChainedContextualRule
  coverage::Optional{Coverage}
  glyph_sequences::Optional{Vector{ChainedSequenceEntry}}
  class_sequences::Optional{Vector{ChainedSequenceEntry}}
  class_definitions::Optional{NTuple{3, ClassDefinition}} # backtrack, input and lookahead classes
  coverage_sequences::Optional{NTuple{3, Vector{Coverage}}} # backtrack, input and lookahead coverages
  coverage_rules::Optional{Vector{Pair{UInt16,UInt16}}} # sequence index => rule index
end

# -----------------------------------
# Conversions from serializable types

function Script(record::ScriptRecord)
  table = record.script_table
  languages = LanguageSystem.(table.lang_sys_records)
  default_language = nothing
  !isnothing(table.default_lang_sys_table) && (default_language = LanguageSystem("dflt", table.default_lang_sys_table.required_feature_index, table.default_lang_sys_table.feature_indices))
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

Coverage(table::CoverageTableFormat1) = Coverage(UnitRange{GlyphID}[], 0, table.glyph_array)
Coverage(table::CoverageTableFormat2) = Coverage([record.start_glyph_id:record.end_glyph_id for record in table.range_records], first(table.range_records).start_coverage_index, GlyphID[])

ClassDefinition(def::ClassDefinitionTableFormat1) = ClassDefinition(RangeClass[], def.class_value_array, def.start_glyph_id)
ClassDefinition(def::ClassDefinitionTableFormat2) = ClassDefinition(RangeClass.(def.class_range_records), ClassID[], 0)
RangeClass(record::ClassRangeRecord) = RangeClass(record.start_glyph_id:record.end_glyph_id, record.class)

sequence_rule(record::SequenceLookupRecord) = record.sequence_index => record.lookup_list_index
SequenceEntry(table::SequenceRuleTable) = SequenceEntry(table.input_sequence, sequence_rule.(table.seq_lookup_records))
sequence_entries(table::SequenceRuleSetTable) = SequenceEntry.(table.seq_rule_tables)

ContextualRule(table::SequenceContextTableFormat1) = ContextualRule(Coverage(table.coverage_table), sequence_entries.(table.seq_rule_set_tables), nothing, nothing, nothing, nothing)
ContextualRule(table::SequenceContextTableFormat2) = ContextualRule(Coverage(table.coverage_table), nothing, sequence_entries.(table.seq_rule_set_tables), ClassDefinition(table.class_def_table), nothing, nothing)
ContextualRule(table::SequenceContextTableFormat3) = ContextualRule(nothing, nothing, nothing, nothing, Coverage.(table.coverage_tables), sequence_rule.(table.seq_lookup_records))

ChainMatch(table::ChainedSequenceRuleTable) = ChainMatch(table.backtrack_sequence, table.input_sequence, table.lookahead_sequence, sequence_rule.(table.seq_lookup_records))
ChainedSequenceEntry(table::ChainedSequenceRuleSetTable) = ChainedSequenceEntry(ChainMatch.(table.chained_seq_rule_tables))
coverage_tables(tables) = Coverage.(tables)

ChainedContextualRule(table::ChainedSequenceContextFormat1) = ChainedContextualRule(Coverage(table.coverage_table), ChainedSequenceEntry.(table.chained_seq_rule_set_tables), nothing, nothing, nothing, nothing)
ChainedContextualRule(table::ChainedSequenceContextFormat2) = ChainedContextualRule(Coverage(table.coverage_table), nothing, ChainedSequenceEntry.(table.chained_class_seq_rule_set_tables), ClassDefinition.((table.backtrack_class_def_table, table.input_class_def_table, table.lookahead_class_def_table)), nothing, nothing)
ChainedContextualRule(table::ChainedSequenceContextFormat3) = ChainedContextualRule(nothing, nothing, nothing, nothing, coverage_tables.((table.backtrack_coverage_tables, table.input_coverage_tables, table.lookahead_coverage_tables)), sequence_rule.(table.seq_lookup_records))

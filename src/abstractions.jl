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

struct SingleSubstitution
  coverage::Coverage
  substitution::Union{GlyphID, Vector{GlyphID}}
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

struct LigatureSubtitution
  coverage::Coverage
  ligatures::Vector{LigatureEntry}
end

struct SequenceEntry
  tail::Vector{GlyphID}
  substitutions::Vector{Pair{UInt16,UInt16}} # Sequence index => Lookup index.
end

struct ContextualSubstitution
  coverage::Coverage
  sequences::Vector{SequenceEntry}
end

function substitute(glyph::GlyphID, pattern::SingleSubstitution)
  i = match(pattern.coverage, glyph)
  !isnothing(i) && return isa(pattern.substitution, GlyphID) ? pattern.substitution : pattern.substitution[i]
  nothing
end

function substitute(glyph::GlyphID, pattern::MultipleSubtitution)
  i = match(pattern.coverage, glyph)
  !isnothing(i) && return pattern.substitutions[i]
  nothing
end

function alternatives(glyph::GlyphID, pattern::AlternateSubtitution)
  i = match(pattern.coverage, glyph)
  !isnothing(i) && return pattern.alternatives[i]
  nothing
end

function substitute(glyphs::Vector{GlyphID}, pattern::LigatureSubtitution)
  head, tail... = glyphs
  i = match(pattern.coverage, head)
  !isnothing(i) && for ligature in pattern.ligatures[i]
      ligature.tail_match == tail && return ligature.substitution
    end
  nothing
end

function contextual_match(f, xs, pattern)
  head, tail... = xs
  if contains(pattern.coverage, head)
    for sequence in pattern.sequences
      sequence.tail_match == tail && return f(xs, sequence)
    end
  end
end

function substitute(glyphs::Vector{GlyphID}, pattern::ContextualSubstitution, lookups)
  contextual_match(glyphs, pattern) do glyphs, sequence
    res = copy(glyphs)
    (; substitutions) = sequence
    unmatched = Set(eachindex(glyphs))
    for (index, lookup_index) in substitutions
      in(index, unmatched) || continue
      new = substitute(glyphs[index], lookups[lookup_index])
      if !isnothing(new)
        res[index] = new
        delete!(unmatched, index)
        isempty(unmatched) && break
      end
    end
    res
  end
end

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

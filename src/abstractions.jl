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

function LanguageSystem(script_tag::Tag, language_tag::Tag, scripts::Vector{Script})
  script_idx = findfirst(x -> x.tag == script_tag, scripts)
  isnothing(script_idx) && error("Script '$script_tag' not found.")
  script = scripts[script_idx]
  language_idx = findfirst(x -> x.tag == language_tag, script.languages)
  !isnothing(language_idx) && return script.languages[language_idx]
  !isnothing(script.default_language) && return script.default_language
  if language_tag ≠ "DFLT"
      language_idx = findfirst(x -> x.tag == "DFLT", script.languages)
      !isnothing(language_idx) && return script.languages[language_idx]
  end
  error("No matching language entry found for the language '$language_tag)'")
end

struct Coverage
  ranges::Vector{UnitRange{UInt16}}
  start_coverage_index::UInt16
  glyphs::Vector{UInt16}
end

function Base.match(coverage::Coverage, glyph::GlyphID)
  for (i, g) in enumerate(coverage.glyphs)
    g == glyph && return i
  end
  for range in coverage.ranges
    in(glyph, range) && return glyph - coverage.start_coverage_index
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

function substitute(glyphs::Vector{GlyphID}, pattern::ContextualSubstitution, lookups)
  head, tail... = glyphs
  i = match(pattern.coverage, head)
  !isnothing(i) && for sequence in pattern.sequences[i]
      if sequence.tail_match == tail
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
        return glyph
      end
    end
  nothing
end

struct RangeClass
  "Range of glyphs by ID which are mapped to this class."
  range::UnitRange{GlyphID}
  "Class which all glyphs in the range are defined to be part of."
  class::Class
end

struct ClassDefinition
  "Classes by glyph range."
  by_range::Vector{RangeClass}
  "Classes by glyph. Glyphs are identified as `i - 1 + start_glyph_id`."
  by_glyph::Vector{Class}
  start_glyph_id::GlyphID
end

function class(glyph::GlyphID, def::ClassDefinition)
  # There should not be any overlap within the same `ClassDefinition`;
  # all glyphs will be assigned a single class or none (class 0 implicitly).
  in(glyph, def.start_glyph_id:(def.start_glyph_id + length(def.by_glyph) - 1)) && return def.by_glyph[1 + (glyph - def.start_glyph_id)]
  for rc in def.by_range
    in(glyph, rc.range) && return rc.class
  end
  zero(Class)
end

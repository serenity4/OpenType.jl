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

function apply_substitution_rule(glyph::GlyphID, pattern::SingleSubstitution)
  i = match(pattern.coverage, glyph)
  !isnothing(i) && return isa(pattern.substitution, GlyphID) ? pattern.substitution : pattern.substitution[i]
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

function apply_substitution_rule(glyphs::Vector{GlyphID}, pattern::LigatureSubtitution)
  head, tail... = glyphs
  i = match(pattern.coverage, head)
  !isnothing(i) && for ligature in pattern.ligatures[i]
      ligature.tail_match == tail && return ligature.substitution
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

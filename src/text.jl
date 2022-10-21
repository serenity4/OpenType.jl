struct Text{T}
  data::Vector{T}
  font::OpenTypeFont
  font_size::Float64
  line_spacing::Float64
  max_line_length::Float64
end

function text(font::OpenTypeFont, str::String, options::TextOptions)
  Text(collect(str), font, options.font_size, options.line_spacing, options.max_line_length)
end

# Style is derived from ANSI character escape codes.
struct CharacterStyle
  bold::Bool
  italic::Bool
  underline::Bool
  strikethrough::Bool
  color::RGBA{Float32}
end

struct StyledChar
  char::Char
  style::CharacterStyle
end

"""
Styling more restrictive than `CharacterStyle`
in that the glyph already has italics and font weight
applied to it (and possibly other stylings).
"""
struct GlyphStyle
  underline::Bool
  strikethrough::Bool
  color::RGBA{Float32}
end

struct StyledGlyph
  glyph::Union{SimpleGlyph,CompositeGlyph}
  style::GlyphStyle
end

function apply_ansi_styling(text::Text{Char})
  styled_chars = StyledChar[]
  for char in text.data
    # TODO
    push!(styled_chars, StyledChar(char, CharacterStyle(false, false, false, false, RGBA(255/255, 255/255, 255/255, 255/255))))
  end
  Text(styled_chars, text.font, text.font_size, text.line_spacing, text.max_line_length)
end

function chars_to_glyphs(text::Text{StyledChar})
  styled_glyphs = map(text.data) do schar
    (; style) = schar
    if style.bold || style.italic
      error("Bold and italic styles are not supported yet.")
    end
    glyph = text.font[schar.char]
    StyledGlyph(glyph, GlyphStyle(style.underline, style.strikethrough, style.color))
  end
  Text(styled_glyphs, text.font, text.font_size, text.line_spacing, text.max_line_length)
end

function apply_glyph_substitutions(text::Text{StyledGlyph})
  styled_glyphs = StyledGlyph[]
  @set text.data = styled_glyphs
end

struct GlyphData
  "0-based index into the buffer of all glyph curves."
  curve_start::UInt32
  "Number of curves to retrieve from the buffer."
  curve_count::UInt32
  color::RGBA{Float32}
end

function text_glyphs(font::OpenTypeFont, str::AbstractString; font_options::FontOptions = FontOptions(), text_options::TextOptions = TextOptions())
  t = text(font, str, text_options)
  t = apply_ansi_styling(t)
  t = chars_to_glyphs(t)
  t = apply_glyph_substitutions(t)
  @assert font_options.apply_ligatures
  @assert font_options.apply_kerning
  # TODO: Restrict features based on user preferences.
  positions = layout_text(font.gpos, t, text_options.script, text_options.language, Set{Tag}())
end

function layout_text(font::OpenTypeFont, glyphs)
  rules = positioning_rules(font.gpos, positioning_features)
end

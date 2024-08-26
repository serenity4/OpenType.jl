Base.@kwdef struct CharacterStyle
  weight::Symbol = :normal
  slant::Symbol = :normal
  underline::Bool = false
  strikethrough::Bool = false
  color::Optional{RGBA{Float32}} = nothing
  background::Optional{RGBA{Float32}} = nothing
  size::Optional{Float64} = nothing
  font::Optional{String} = nothing
end

tryparse_color(value::Symbol) = tryparse_color(string(value))
tryparse_color(value::Colorant) = value
function tryparse_color(value::AbstractString)
  try
    parse(Colorant, replace(value, ';' => ','))
  catch e
    isa(e, InterruptException) && rethrow()
    @debug "Ignoring color attribute with unrecognized value `$value`"
  end
end

function CharacterStyle(annotations::AbstractVector{<:Pair{Symbol}})
  size = font = nothing
  face = getface(annotations)
  color = extract_color(face.foreground)
  background = extract_color(face.background)
  for (label, value) in annotations
    label_str = string(label)
    endswith(label_str, ' ') && (label = Symbol(strip(label_str)))
    label === :color && (color = something(tryparse_color(value), Some(color)))
    label === :background && (background = something(tryparse_color(value), Some(background)))
    label === :size && (size = isa(value, String) ? parse(Float64, value) : convert(Float64, value))
    label === :font && (font = value)
  end
  CharacterStyle(; face.weight, face.slant, face.underline, face.strikethrough, color, background, size, font)
end

function extract_color(color::StyledStrings.SimpleColor)
  color == StyledStrings.SimpleColor(:default) && return nothing
  (; value) = color
  isa(value, Symbol) && return something(tryparse_color(value), Some(color))
  RGB{N0f8}(value.r, value.g, value.b)
end

@enum FontSizeSpec::UInt8 begin
  FONT_SIZE_FIXED
  FONT_SIZE_MUST_FIT
  FONT_SIZE_FILL_AVAILABLE
end

"""
    FontSize(value::Real; reduce_to_fit::Bool = true) # ideal value provided, may be reduced to fit if allowed
    FontSize(value::Nothing; kwargs...) # will fill available space
    FontSize() # will fill available space

Specify how the font should be sized.
"""
struct FontSize
  value::Float64
  type::FontSizeSpec
end

FontSize() = FontSize(0.0, FONT_SIZE_FILL_AVAILABLE)
FontSize(::Nothing; kwargs...) = FontSize()
FontSize(value::Real; reduce_to_fit::Bool = true) = FontSize(value, reduce_to_fit ? FONT_SIZE_MUST_FIT : FONT_SIZE_FIXED)

function Base.show(io::IO, ::MIME"text/plain", size::FontSize)
  print(io, FontSize, '(')
  size.type == FONT_SIZE_FIXED && print(io, size.value)
  size.type == FONT_SIZE_MUST_FIT && print(io, size.value, ", may be reduced to fit")
  size.type == FONT_SIZE_FILL_AVAILABLE && print(io, "fill available space")
  print(io, ')')
end

struct FontOptions
  shaping_options::ShapingOptions
  font_size::FontSize
  variable_coordinates::Vector{Any}
end

FontOptions(shaping_options::ShapingOptions, font_size::FontSize) = FontOptions(shaping_options, font_size, [])
FontOptions(shaping_options::ShapingOptions, font_size::Real) = FontOptions(shaping_options, FontSize(font_size))

@enum TextLimitsSpec::UInt8 begin
  TEXT_LIMITS_NONE
  TEXT_LIMITS_WIDTH_FIXED
  TEXT_LIMITS_FIXED
end

struct TextLimits
  width::Float64
  height::Float64
  type::TextLimitsSpec
end

TextLimits() = TextLimits(0.0, 0.0, TEXT_LIMITS_NONE)
TextLimits(width::Real) = TextLimits(width, 0.0, TEXT_LIMITS_WIDTH_FIXED)
TextLimits(width::Real, height::Real) = TextLimits(width, height, TEXT_LIMITS_FIXED)

function Base.show(io::IO, ::MIME"text/plain", limits::TextLimits)
  print(io, TextLimits, '(')
  limits.type == TEXT_LIMITS_NONE && print(io, "no limits")
  limits.type == TEXT_LIMITS_WIDTH_FIXED && print(io, "fixed width, no height limit")
  limits.type == TEXT_LIMITS_FIXED && print(io, "fixed width and height")
  print(io, ')')
end

Base.@kwdef struct TextOptions
  line_spacing::Float64 = 1
  limits::TextLimits = TextLimits()
  language::Tag4 = tag"dflt"
end

struct Text
  chars::Vector{Char}
  style_changes::Vector{Pair{Int64,CharacterStyle}}
  options::TextOptions
end

fallback_style() = CharacterStyle()

extract_style_from_text(text::AbstractString) = [1 => fallback_style()]

function extract_style_from_text(text::Base.AnnotatedString)
  style_changes = Pair{Int64, CharacterStyle}[]
  sizehint!(style_changes, 50)
  i = 1
  for (region, annotations) in eachregion(text)
    push!(style_changes, i => CharacterStyle(annotations))
    i += length(region)
  end
  style_changes
end

function Text(text::AbstractString, options::TextOptions)
  chars = collect(Char, text)
  style_changes = extract_style_from_text(text)
  Text(chars, style_changes, options)
end

function assign_scripts(chars::AbstractVector{Char})
  recently_used = Tag4[]
  scripts = Tag4[]
  for i in eachindex(chars)
    script = find_script(chars, i, recently_used)
    push!(scripts, script)
    isempty(recently_used) && (pushfirst!(recently_used, script); continue)
    script == @inbounds(recently_used[1]) && continue
    j = findfirst(==(script), recently_used)
    isnothing(j) && (pushfirst!(recently_used); continue)
    @inbounds recently_used[1], recently_used[j] = recently_used[j], recently_used[i]
  end
  scripts
end

struct SplitLine
  chars::Vector{Char}
  text_offset::Int64
  text_style_changes::Vector{Pair{Int64,CharacterStyle}}
end

struct TextRun
  range::UnitRange{Int64}
  font::OpenTypeFont
  options::FontOptions
  style::CharacterStyle
  script::Tag4
end

# TODO: Actually check for font coverage.
has_font_coverage(char::Char, font::OpenTypeFont) = true

"""
Compute runs across portions of text segmented by unique combinations of:
- Applicable font (with font coverage heuristics using a list of fallbacks font).
- Character style (italic, bold, color, size).
- Script ('latn' for Latin, 'grek' for Greek, 'laoo' for Lao...)

Every run is to be conducted for a single line of text, though shaping may still be used first to identify suitable line breaks.
"""
function compute_runs(line::SplitLine, fonts::AbstractVector{Pair{OpenTypeFont, FontOptions}})
  runs = TextRun[]
  scripts = assign_scripts(line.chars)
  (start, last_script, last_style, last_font) = (1, scripts[1], 1, 1)
  for (i, char) in enumerate(line.chars)
    script = scripts[i]
    style_index = findlast(≤(i + line.text_offset) ∘ first, line.text_style_changes)
    # If no font supports the character, select the first font
    # and rely on its fallback to insert a null glyph.
    font_index = something(findfirst(font -> has_font_coverage(char, font[1]), fonts), 1)
    script == last_script && style_index == last_style && font_index == last_font && i ≠ lastindex(line.chars) && continue
    (font, font_options) = fonts[last_font]
    _, style = line.text_style_changes[last_style]
    stop = i
    push!(runs, TextRun(start:stop, font, font_options, style, last_script))
    (start, last_script, last_style, last_font) = (i + 1, script, style_index, font_index)
  end
  runs
end

struct GlyphStyle
  color::Optional{RGBA{Float32}}
  background::Optional{RGBA{Float32}}
  underline::Bool
  strikethrough::Bool
  size::Float64
end

GlyphStyle(style::CharacterStyle, size = 0.0) = GlyphStyle(style.color, style.background, style.underline, style.strikethrough, size)
function GlyphStyle(run::TextRun)
  style = GlyphStyle(run.style)
  @set style.size = glyph_size(run)
end
GlyphStyle() = GlyphStyle(CharacterStyle())

glyph_size(run::TextRun) = something(run.style.size, run.options.font_size.value) / run.font.units_per_em

struct LineSegment
  indices::UnitRange{Int64}
  font::OpenTypeFont
  options::FontOptions
  style::GlyphStyle
end

struct Line
  """
  Glyph indices into `outlines`. Has the same number of components as `positions`.

  A value of 0 means that the glyph has no outlines.
  """
  glyphs::Vector{Int64}
  "Relative positions with respect to the line start."
  positions::Vector{Point2}
  "Segments of the line that were shaped independently."
  segments::Vector{LineSegment}
  """
  Materialized glyph outlines (i.e. without implicit points), after scaling but before positioning within the line.
  A given glyph appearing multiple times in a line will have the same outlines.
  """
  outlines::Vector{Vector{GlyphOutline}}
end

Base.show(io::IO, line::Line) = print(io, Line, '(', length(line.glyphs), " glyphs, ", length(line.segments), " segments)")

function split_lines(text::Text)
  newlines = findall(==('\n'), text.chars)
  push!(newlines, 1 + lastindex(text.chars))
  lines = SplitLine[]
  prev = 0
  for i in newlines
    range = (prev + 1):(i - 1)
    prev = i
    isempty(range) && continue
    push!(lines, SplitLine(text.chars[range], range.start, text.style_changes))
  end
  lines
end

function lines(text::Text, fonts::AbstractVector{Pair{OpenTypeFont, FontOptions}})
  lines = Line[]
  for line in split_lines(text)
    glyph_indices = Dict{Pair{GlyphID, OpenTypeFont}, Int64}()
    line_glyphs, line_positions = GlyphID[], Point2[]
    outlines = Vector{GlyphOutline}[]
    segments = LineSegment[]
    runs = compute_runs(line, fonts)
    last_advance = nothing
    for run in runs
      glyphs, offsets = shape(run.font, @view(line.chars[run.range]), run.options.shaping_options)
      segment = LineSegment(run.range, run.font, run.options, GlyphStyle(run))
      push!(segments, segment)
      start = isempty(line_positions) ? zero(Point2) : line_positions[end] .+ last_advance
      append!(line_positions, compute_positions(offsets, start, segment.style.size))
      last_advance = offsets[end].advance .* segment.style.size
      for glyph in glyphs
        i = get!(glyph_indices, glyph => run.font) do
          g = run.font[glyph]
          isnothing(g) && return 0
          geometry = curves(g)
          push!(outlines, geometry)
          lastindex(outlines)
        end
        push!(line_glyphs, i)
      end
    end
    push!(lines, Line(line_glyphs, line_positions, segments, outlines))
  end
  lines
end

function compute_positions(offsets, start, scale)
  positions = Point2[]
  for offset in offsets
    push!(positions, start .+ offset.origin .* scale)
    start = start .+ offset.advance .* scale
  end
  positions
end

function boundingelement(line::Line, segment::LineSegment)
  res = nothing
  (; size) = segment.style
  for i in segment.indices
    glyph = line.glyphs[i]
    iszero(glyph) && continue
    position = line.positions[i]
    outlines = line.outlines[glyph] .* size
    geometry = boundingelement(outlines) + position
    res = isnothing(res) ? geometry : boundingelement(res, geometry)
  end
  res
end
boundingelement(line::Line) = boundingelement(boundingelement(line, segment) for segment in line.segments if any(i -> !iszero(line.glyphs[i]), segment.indices))
boundingelement(text::Text, fonts) = boundingelement(lines(text, fonts))

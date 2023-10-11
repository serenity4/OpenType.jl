function Base.show(io::IO, font::OpenTypeFont)
  print(io, "OpenType font (", length(font.glyphs), " glyphs", ", last modified: ", font.modified)
  isnothing(font.gpos) && print(io, ", no glyph positioning table")
  isnothing(font.gsub) && print(io, ", no glyph substitution table")
  print(io, ')')
end

direction_string(direction::Direction) = ("left to right", "right to left", "bottom to top", "top to bottom")[findfirst(==(direction), (DIRECTION_LEFT_TO_RIGHT, DIRECTION_RIGHT_TO_LEFT, DIRECTION_BOTTOM_TO_TOP, DIRECTION_TOP_TO_BOTTOM))]

function Base.show(io::IO, ::MIME"text/plain", options::ShapingOptions)
  print(io, ShapingOptions, "(direction = ", direction_string(options.direction), ", script = ", repr(options.script), ", language = ", repr(options.language), ", extra_features = ", sort!(collect(options.enabled_features)), ", disabled features = ", sort!(collect(options.disabled_features)), ')')
end

function Base.show(io::IO, mime::MIME"text/plain", options::FontOptions)
  print(io, FontOptions, '(')
  show(io, mime, options.font_size)
  print(io, " with ")
  show(io, mime, options.shaping_options)
  print(io, ')')
end

function Base.show(io::IO, mime::MIME"text/plain", segment::LineSegment)
  print(io, LineSegment, '(')
  show(io, mime, segment.indices)
  print(io, ", ")
  show(io, mime, segment.font)
  print(io, ", ")
  show(io, mime, segment.options)
  print(io, ')')
end

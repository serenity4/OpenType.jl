struct ShapingOptions
  "OpenType or ISO-15924 script tag."
  script::Tag4
  "ISO-639-1, ISO-639-3 or OpenType language tag."
  language::Union{Tag2,Tag3,Tag4}
  direction::Direction
  enabled_features::Set{Tag4}
  disabled_features::Set{Tag4}
end

ShapingOptions(script, language, direction::Direction = DIRECTION_LEFT_TO_RIGHT; enabled_features = Tag4[], disabled_features = Tag4[]) = ShapingOptions(script, language, direction, Set(@something(enabled_features, Tag4[])), Set(@something(disabled_features, Tag4[])))

include("shaping/harfbuzz.jl")
include("shaping/julia.jl")

function shape(font::OpenTypeFont, text, options::ShapingOptions; kwargs...)
  # XXX: If we don't have a font file, we could create a Freetype font
  # when reading from the IO and pass that into HarfBuzz.
  # XXX: Currently segfaults on hb_ot_tags_from_script_and_language for unknown reasons.
  # hb_shape(font.file::String, text, options; kwargs...)
  jl_shape(font, text, options; kwargs...)
end

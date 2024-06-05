include("generated/tags.jl")

function find_language_tag(tag::Tag4)
  tag = uppercase(tag)
  haskey(language_tag_names_opentype, tag) ? tag : nothing
end

function find_language_tag(tag::Tag3)
  tag = lowercase(tag)
  ret = get(language_tags_ISO_639_3_to_opentype, tag, nothing)
  !isnothing(ret) && return ret
  macro_tag = get(macrolanguages_ISO_639_3, tag, nothing)
  !isnothing(macro_tag) && return find_language_tag(macro_tag)
  find_language_tag(Tag4((tag.data..., ' ')))
end

function find_language_tag(tag::Tag2)
  tag = lowercase(tag)
  ret = get(language_tags_ISO_639_1_ISO_639_3, tag, nothing)
  !isnothing(ret) && return find_language_tag(ret)
  nothing
end

function find_script_tag(tag::Tag4)
  # Allow ISO-15924 script tags.
  tag = Tag((UInt8(lowercase(Char(tag.data[1]))), tag.data[2:end]...))
  haskey(script_tags_opentype, tag) ? tag : nothing
end

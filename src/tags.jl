"N-string tag."
struct Tag{N}
  data::NTuple{N, UInt8}
end

function Tag{N}(str::AbstractString) where {N}
  chars = collect(str)
  length(chars) == N || error("Expected $N-character string for tag, got string \"$str\" with length $(length(chars)).")
  for c in chars
    isascii(c) || error("Tags must be ASCII strings, got non-ASCII character '$c' for \"$str\".")
  end
  Tag(ntuple(i -> UInt8(chars[i]), N))
end

Tag(str::AbstractString) = Tag{length(str)}(str)

const Tag2 = Tag{2}
const Tag3 = Tag{3}
const Tag4 = Tag{4}

Base.uppercase(tag::Tag) = Tag(UInt8.((uppercase.(Char.(tag.data)))))
Base.lowercase(tag::Tag) = Tag(UInt8.((lowercase.(Char.(tag.data)))))

macro tag_str(str) Tag(str) end
macro tag2_str(str) Tag2(str) end
macro tag3_str(str) Tag3(str) end
macro tag4_str(str) Tag4(str) end

Base.read(io::IO, T::Type{Tag{N}}) where {N} = T(ntuple(_ -> read(io, UInt8), N))
Base.show(io::IO, tag::Tag) = print(io, '"', join(Char.(tag.data)), '"')
Base.string(tag::Tag) = join(Char.(tag.data))
Base.convert(::Type{Tag}, str::AbstractString) = Tag(str)
Base.convert(::Type{Tag{N}}, str::AbstractString) where {N} = Tag{N}(str)

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

struct hb_feature_t
  tag::UInt32
  value::UInt32
  start::UInt32
  _end::UInt32
end

function hb_feature_t(tag::Tag4, enabled::Bool)
  tag = @ccall libharfbuzz.hb_tag_from_string(string(tag)::Cstring, (-1)::Cint)::UInt32
  hb_feature_t(tag, enabled, 0, typemax(UInt32))
end

function hb_features(options::ShapingOptions)
  features = hb_feature_t[]
  for feature in options.enabled_features
    push!(features, hb_feature_t(feature, true))
  end
  for feature in options.disabled_features
    push!(features, hb_feature_t(feature, false))
  end
  features
end

function Base.show(io::IO, feature::hb_feature_t)
  buff = zeros(Cchar, 128)
  @ccall libharfbuzz.hb_feature_to_string(Ref(feature)::Ptr{hb_feature_t}, buff::Ptr{Cchar}, 128::Cuint)::Cvoid
  GC.@preserve buff begin
    print(io, unsafe_string(pointer(buff)))
  end
end

struct hb_glyph_info_t
  codepoint::UInt32
  mask::UInt32 # private
  cluster::UInt32
  var1::UInt32 # private
  var2::UInt32 # private
end

Base.show(io::IO, info::hb_glyph_info_t) = print(io, hb_glyph_info_t, "(codepoint: ", repr(info.codepoint), ", cluster: ", info.cluster, ')')

struct hb_glyph_position_t
  x_advance::Int32
  y_advance::Int32
  x_offset::Int32
  y_offset::Int32
  var::UInt32 # private
end

OpenType.GlyphOffset(info::hb_glyph_position_t) = GlyphOffset(info.x_offset, info.y_offset, info.x_advance, info.y_advance)

const CEnum_T = Int16

hb_direction(direction::AbstractString) = @ccall libharfbuzz.hb_direction_from_string(direction::Cstring, (-1)::Int16)::CEnum_T
hb_direction(direction::Direction) = hb_direction(direction == DIRECTION_LEFT_TO_RIGHT ? "LTR" : direction == DIRECTION_RIGHT_TO_LEFT ? "RTL" : direction == DIRECTION_TOP_TO_BOTTOM ? "TTB" : "BTT")

function hb_shape(font_file::AbstractString, text::AbstractVector{Char}, options::ShapingOptions)
  hb_shape(font_file, String(text), options)
end

function hb_shape(font_file::AbstractString, text::AbstractString, options::ShapingOptions)
  blob = @ccall libharfbuzz.hb_blob_create_from_file(font_file::Cstring)::Ptr{Nothing}
  face = @ccall libharfbuzz.hb_face_create(blob::Ptr{Nothing}, 0::UInt16)::Ptr{Nothing}
  font = @ccall libharfbuzz.hb_font_create(face::Ptr{Nothing})::Ptr{Nothing}
  buffer = @ccall libharfbuzz.hb_buffer_create()::Ptr{Nothing}

  direction = hb_direction(options.direction)
  script = @ccall libharfbuzz.hb_script_from_string(string(options.script)::Cstring, (-1)::Int16)::UInt32
  language = @ccall libharfbuzz.hb_language_from_string(string(options.language)::Cstring, (-1)::Int16)::UInt32

  @ccall libharfbuzz.hb_buffer_add_utf8(buffer::Ptr{Nothing}, text::Cstring, (-1)::Int16, 0::UInt16, (-1)::Int16)::Ptr{Nothing}
  @ccall libharfbuzz.hb_buffer_set_direction(buffer::Ptr{Nothing}, direction::CEnum_T)::Ptr{Nothing}
  @ccall libharfbuzz.hb_buffer_set_script(buffer::Ptr{Nothing}, script::UInt32)::Ptr{Nothing}
  @ccall libharfbuzz.hb_buffer_set_language(buffer::Ptr{Nothing}, language::UInt32)::Ptr{Nothing}

  user_features = hb_features(options)
  @ccall libharfbuzz.hb_shape(font::Ptr{Nothing}, buffer::Ptr{Nothing}, user_features::Ptr{hb_feature_t}, length(user_features)::UInt16)::Ptr{Nothing}

  glyph_count = Ref{UInt16}(0)
  glyph_info_ptr = @ccall libharfbuzz.hb_buffer_get_glyph_infos(buffer::Ptr{Nothing}, glyph_count::Ptr{UInt16})::Ptr{hb_glyph_info_t}
  glyph_pos_ptr = @ccall libharfbuzz.hb_buffer_get_glyph_positions(buffer::Ptr{Nothing}, glyph_count::Ptr{UInt16})::Ptr{hb_glyph_position_t}

  infos = copy(unsafe_wrap(Array, glyph_info_ptr, glyph_count[]))
  positions = copy(unsafe_wrap(Array, glyph_pos_ptr, glyph_count[]))

  @ccall libharfbuzz.hb_buffer_destroy(buffer::Ptr{Nothing})::Ptr{Nothing}
  @ccall libharfbuzz.hb_font_destroy(font::Ptr{Nothing})::Ptr{Nothing}
  @ccall libharfbuzz.hb_face_destroy(face::Ptr{Nothing})::Ptr{Nothing}
  @ccall libharfbuzz.hb_blob_destroy(blob::Ptr{Nothing})::Ptr{Nothing}

  indices = GlyphID[info.codepoint for info in infos]
  offsets = map(GlyphOffset, positions)
  indices, offsets
end

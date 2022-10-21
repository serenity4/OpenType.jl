using HarfBuzz_jll: libharfbuzz

struct hb_feature_t
  tag::UInt32
  value::UInt32
  start::UInt16
  _end::UInt16
end

struct hb_glyph_info_t
  codepoint::UInt32
  mask::UInt32 # private
  cluster::UInt32
  var1::UInt32 # private
  var2::UInt32 # private
end

struct hb_glyph_position_t
  x_advance::Int32
  y_advance::Int32
  x_offset::Int32
  y_offset::Int32
  var::UInt32 # private
end

const CEnum_T = Int16

function hb_shape(font_file::AbstractString, text::AbstractString)
  blob = @ccall libharfbuzz.hb_blob_create_from_file(font_file::Cstring)::Ptr{Nothing}
  face = @ccall libharfbuzz.hb_face_create(blob::Ptr{Nothing}, 0::UInt16)::Ptr{Nothing}
  font = @ccall libharfbuzz.hb_font_create(face::Ptr{Nothing})::Ptr{Nothing}
  buffer = @ccall libharfbuzz.hb_buffer_create()::Ptr{Nothing}

  direction = @ccall libharfbuzz.hb_direction_from_string("LTR"::Cstring, (-1)::Int16)::CEnum_T
  script = @ccall libharfbuzz.hb_script_from_string("Latn"::Cstring, (-1)::Int16)::UInt32
  language = @ccall libharfbuzz.hb_language_from_string("fr-FR"::Cstring, (-1)::Int16)::UInt32

  @ccall libharfbuzz.hb_buffer_add_utf8(buffer::Ptr{Nothing}, text::Cstring, (-1)::Int16, 0::UInt16, (-1)::Int16)::Ptr{Nothing}
  @ccall libharfbuzz.hb_buffer_set_direction(buffer::Ptr{Nothing}, direction::CEnum_T)::Ptr{Nothing}
  @ccall libharfbuzz.hb_buffer_set_script(buffer::Ptr{Nothing}, script::UInt32)::Ptr{Nothing}
  @ccall libharfbuzz.hb_buffer_set_language(buffer::Ptr{Nothing}, language::UInt32)::Ptr{Nothing}

  @ccall libharfbuzz.hb_shape(font::Ptr{Nothing}, buffer::Ptr{Nothing}, C_NULL::Ptr{hb_feature_t}, 0::UInt16)::Ptr{Nothing}

  glyph_count = Ref{UInt16}(0)
  glyph_info_ptr = @ccall libharfbuzz.hb_buffer_get_glyph_infos(buffer::Ptr{Nothing}, glyph_count::Ptr{UInt16})::Ptr{hb_glyph_info_t}
  glyph_pos_ptr = @ccall libharfbuzz.hb_buffer_get_glyph_positions(buffer::Ptr{Nothing}, glyph_count::Ptr{UInt16})::Ptr{hb_glyph_position_t}

  infos = copy(unsafe_wrap(Array, glyph_info_ptr, glyph_count[]))
  positions = copy(unsafe_wrap(Array, glyph_pos_ptr, glyph_count[]))

  @ccall libharfbuzz.hb_buffer_destroy(buffer::Ptr{Nothing})::Ptr{Nothing}
  @ccall libharfbuzz.hb_font_destroy(font::Ptr{Nothing})::Ptr{Nothing}
  @ccall libharfbuzz.hb_face_destroy(face::Ptr{Nothing})::Ptr{Nothing}
  @ccall libharfbuzz.hb_blob_destroy(blob::Ptr{Nothing})::Ptr{Nothing}

  (infos, positions)
end

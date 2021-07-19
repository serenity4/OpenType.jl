struct TableRecord
    tag::String
    checksum::UInt32
    offset::UInt32
    length::UInt32
end

@enum PlatformID::UInt16 begin
    UNICODE   = 0
    MACINTOSH = 1
    ISO       = 2
    WINDOWS   = 3
    CUSTOM    = 4
end

@enum EncodingUnicode::UInt16 begin
    UNICODE_1_0                 = 0
    UNICODE_1_1                 = 1
    ISO_IEC_10646               = 2
    UNICODE_2_0_BMP             = 3
    UNICODE_2_0_FULL            = 4
    UNICODE_VARIATION_SEQUENCES = 5
    UNICODE_FULL                = 6
end

abstract type CmapSubtable end

struct SequentialMapGroup
    char_range::UnitRange{UInt32}
    start_glyph_id::UInt32
end

const ManyToOneRangeMappings = SequentialMapGroup

struct SegmentedCoverage <: CmapSubtable
    groups::Vector{SequentialMapGroup}
end

struct ByteEncodingTable <: CmapSubtable
    glyph_id_array::Vector{UInt8}
end


struct EncodingRecord
    platform_id::PlatformID
    encoding_id::UInt16
    subtable_offset::UInt32
end

struct CharToGlyph
    encoding_records::Vector{EncodingRecord}
    tables::Dict{Int,CmapSubtable}
end

struct FontHeader
    flags::UInt16
    units_per_em::UInt16
    created::DateTime
    modified::DateTime
    xmin::Int16
    ymin::Int16
    xmax::Int16
    ymax::Int16
    mac_style::UInt16
    min_readable_size::Int16
    font_direction_hint::Int16
    index_to_loc_format::Int16
    glyph_data_format::Int16
end

struct GlyphHeader
    ncontours::Int16
    xmin::Int16
    ymin::Int16
    xmax::Int16
    ymax::Int16
end

struct MaximumProfile
    version::VersionNumber
    nglyphs::UInt16
    max_points::UInt16
    max_contours::UInt16
    max_composite_points::UInt16
    max_composite_contours::UInt16
    max_zones::UInt16
    max_twilight_points::UInt16
    max_storage::UInt16
    max_function_defs::UInt16
    max_instruction_defs::UInt16
    max_stack_elements::UInt16
    max_size_of_instructions::UInt16
    max_component_elements::UInt16
    max_component_depth::UInt16
end

abstract type GlyphData end

@bitmask_flag SimpleGlyphFlag::UInt8 begin
    ON_CURVE_POINT_BIT =                       0x01
    X_SHORT_VECTOR_BIT =                       0x02
    Y_SHORT_VECTOR_BIT =                       0x04
    REPEAT_FLAG_BIT =                          0x08
    X_IS_SAME_OR_POSITIVE_X_SHORT_VECTOR_BIT = 0x10
    Y_IS_SAME_OR_POSITIVE_Y_SHORT_VECTOR_BIT = 0x20
    OVERLAP_SIMPLE_BIT =                       0x40
    SIMPLE_GLYPH_RESERVED_BIT =                0x80
end

struct GlyphPoint
    coords::Point{2,Int}
    on_curve::Bool
end

"""
Description of a glyph as a series of quadratic bezier patches.

Bezier patches are implicitly defined using a list of `GlyphPoint`s, where two consecutive off-curve points implicitly define an on-curve point halfway.
"""
struct GlyphSimple <: GlyphData
    contour_indices::Vector{Int}
    points::Vector{GlyphPoint}
end

Base.show(io::IO, gdata::GlyphSimple) = print(io, "GlyphSimple(", length(gdata.points), " points, ", length(gdata.contour_indices), " indices)")

struct Glyph{D<:GlyphData}
    header::GlyphHeader
    data::D
end

struct OpenTypeFont
    cmap::CharToGlyph
    head::FontHeader
    hhea
    hmtx
    maxp::MaximumProfile
    name
    os_2
    post
    glyphs::Vector{Glyph}
end

struct OpenTypeCollection
end

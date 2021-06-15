struct TableRecord
    tag::String
    checksum::UInt32
    offset::Int
    length::Int
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

struct GlyphSimple
    control_points::NTuple{3,Float32}
end

struct OpenTypeFont
    cmap
    head
    hhea
    hmtx
    maxp::MaximumProfile
    name
    os_2
    post
end

struct OpenTypeCollection
end

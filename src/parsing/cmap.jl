@enum PlatformID::UInt16 begin
    UNICODE   = 0
    MACINTOSH = 1
    ISO       = 2
    WINDOWS   = 3
    CUSTOM    = 4
end

@enum UnicodeEncodingID::UInt16 begin
    UNICODE_1_0                 = 0
    UNICODE_1_1                 = 1
    ISO_IEC_10646               = 2
    UNICODE_2_0_BMP             = 3
    UNICODE_2_0_FULL            = 4
    UNICODE_VARIATION_SEQUENCES = 5
    UNICODE_FULL                = 6
end

@enum ISOEncodingID::UInt16 begin
    ASCII_7_BIT = 0
    ISO_10646   = 1
    ISO_8859_1  = 2
end

@enum WindowsEncodingID::UInt16 begin
    WINDOWS_ENCODING_SYMBOL = 0
    WINDOWS_ENCODING_UNICODE_BMP = 1
    WINDOWS_ENCODING_SHIFT_JIS = 2
    WINDOWS_ENCODING_PRC = 3
    WINDOWS_ENCODING_BIG5 = 4
    WINDOWS_ENCODING_WANSUNG = 5
    WINDOWS_ENCODING_JOHAB = 6
    WINDOWS_ENCODING_RESERVED_1 = 7
    WINDOWS_ENCODING_RESERVED_2 = 8
    WINDOWS_ENCODING_RESERVED_3 = 9
    WINDOWS_ENCODING_UNICODE_FULL = 10
end

@serializable struct EncodingRecord
    platform_id::PlatformID
    encoding_id::UInt16
    subtable_offset::UInt32
end

abstract type CmapSubtable{N} end

Base.read(io::IO, ::Type{CmapSubtable}) = read(io, CmapSubtable{Int(peek(io, UInt16))})

@serializable struct ByteEncodingTable <: CmapSubtable{0}
    format::UInt16
    length::UInt16
    language::UInt16
    glyph_id_array::Vector{UInt8} => 256
end

Base.read(io::IO, ::Type{CmapSubtable{0}}) = read(io, ByteEncodingTable)

@serializable struct SubHeaderRecord
    first_code::UInt16
    entry_count::UInt16
    id_delta::Int16
    id_range_offset::UInt16
end

"""
See the reference from [Apple's TrueType](https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6cmap.html)
('cmap' format 2) for more information about this table.
"""
@serializable struct HighByteMappingThroughTable <: CmapSubtable{2}
    format::UInt16
    length::UInt16
    language::UInt16
    sub_header_keys::Vector{UInt16} => 256
    sub_headers::Vector{SubHeaderRecord} => maximum(sub_header_keys) ÷ 8
    glyph_id_array::Vector{UInt16} => maximum(sub_header_keys) ÷ 8
end

Base.read(io::IO, ::Type{CmapSubtable{2}}) = read(io, HighByteMappingThroughTable)

@serializable struct SegmentMappingToDeltaValues <: CmapSubtable{4}
    format::UInt16
    length::UInt16
    language::UInt16
    segcount_x2::UInt16
    search_range::UInt16
    entry_selector::UInt16
    range_shift::UInt16
    end_code::Vector{UInt16} => segcount_x2 ÷ 2
    reserved_pad::UInt16
    start_code::Vector{UInt16} => segcount_x2 ÷ 2
    id_delta::Vector{Int16} => segcount_x2 ÷ 2
    id_range_offsets::Vector{UInt16} => segcount_x2 ÷ 2
    # This array runs until the end of the table, as indicated by the `length` field.
    # The number of elements is computed based on the number of bytes remaining from
    # the current position and on the field size (2 bytes).
    glyph_id_array::Vector{UInt16} => (length - (position(io) - __origin__)) ÷ 2
end

Base.read(io::IO, ::Type{CmapSubtable{4}}) = read(io, SegmentMappingToDeltaValues)

@serializable struct TrimmedTableMapping <: CmapSubtable{6}
    format::UInt16
    length::UInt16
    language::UInt16
    first_code::UInt16
    entry_count::UInt16
    glyph_id_array::Vector{UInt16} => entry_count
end

Base.read(io::IO, ::Type{CmapSubtable{6}}) = read(io, TrimmedTableMapping)

@serializable struct SequentialMapGroupRecord
    start_char_code::UInt32
    end_char_chode::UInt32
    start_glyph_id::UInt32
end

@serializable struct Mixed16And32BitCoverage <: CmapSubtable{8}
    format::UInt16
    reserved::UInt16
    length::UInt32
    language::UInt32
    is_32::Vector{UInt8} => 8192
    num_groups::UInt32
    groups::SequentialMapGroupRecord
end

Base.read(io::IO, ::Type{CmapSubtable{8}}) = read(io, Mixed16And32BitCoverage)

@serializable struct TrimmedArray <: CmapSubtable{10}
    format::UInt16
    reserved::UInt16
    length::UInt32
    language::UInt32
    start_char_code::UInt32
    num_chars::UInt32
    glyph_id_array::Vector{UInt16} => num_chars
end

Base.read(io::IO, ::Type{CmapSubtable{10}}) = read(io, TrimmedArray)

@serializable struct SegmentedCoverage <: CmapSubtable{12}
    format::UInt16
    reserved::UInt16
    length::UInt32
    language::UInt32
    num_groups::UInt32
    groups::Vector{SequentialMapGroupRecord} => num_groups
end

Base.read(io::IO, ::Type{CmapSubtable{12}}) = read(io, SegmentedCoverage)

@serializable struct ConstantMapGroupRecord
    start_char_code::UInt32
    end_char_chode::UInt32
    start_glyph_id::UInt32
end

@serializable struct ManyToOneRangeMappings <: CmapSubtable{13}
    format::UInt16
    reserved::UInt16
    length::UInt32
    language::UInt32
    num_groups::UInt32
    groups::Vector{SequentialMapGroupRecord} => num_groups
end

Base.read(io::IO, ::Type{CmapSubtable{13}}) = read(io, ManyToOneRangeMappings)

struct VariationSelectorRecord
    # This field is actually typed to UInt24 in OpenType.
    var_selector::UInt32
    default_uvs_offset::UInt32
    non_default_uvs_offset::UInt32
end

function Base.read(io::IO, ::Type{VariationSelectorRecord})
    # Parse UInt24 in UInt32, padding with zeros.
    var_selector = read(io, UInt32) >> 8
    seek(io, position(io) - 1)
    VariationSelectorRecord(var_selector, read(io, UInt32), read(io, UInt32))
end

struct UnicodeRange
    start_unicode_value::UInt32 # UInt24
    additional_count::UInt8
end

function Base.read(io::IO, ::Type{UnicodeRange})
    val = read(io, UInt32)
    UnicodeRange(val >> 8, val << 16)
end

@serializable struct DefaultUVSTable
    num_unicode_value_ranges::UInt32
    ranges::Vector{UnicodeRange} => num_unicode_value_ranges
end

struct UVSMappingRecord
    unicode_value::UInt32 # UInt24
    glyph_id::UInt16
end

function Base.read(io::IO, ::Type{UVSMappingRecord})
    # Parse UInt24 in UInt32, padding with zeros.
    unicode_value = read(io, UInt32) >> 8
    seek(io, position(io) - 1)
    VariationSelectorRecord(unicode_value, read(io, UInt16))
end

@serializable struct NonDefaultUVSTable
    num_uvs_mappings::UInt32
    uvs_mappings::Vector{UVSMappingRecord} => num_uvs_mappings
end

struct UnicodeVariationSequences <: CmapSubtable{14}
    format::UInt16
    length::UInt32
    num_var_selector_records::UInt32
    var_selectors::Vector{VariationSelectorRecord}
    uvs_tables::Vector{Union{DefaultUVSTable,NonDefaultUVSTable}}
end

Base.read(io::IO, ::Type{CmapSubtable{14}}) = read(io, UnicodeVariationSequences)

function Base.read(io::IO, ::Type{UnicodeVariationSequences})
    pos = position(io)
    format, length, num_var_selector_records = Tuple(read(io, T) for T in fieldtypes(UnicodeVariationSequences)[1:end-1])
    var_selectors = [read(io, VariationSelectorRecord) for _ in 1:num_var_selector_records]
    uvs_tables = Union{DefaultUVSTable,NonDefaultUVSTable}[]
    for selector in var_selectors
        if !iszero(selector.default_uvs_offset)
            seek(io, pos + selector.default_uvs_offset)
            push!(uvs_tables, read(io, DefaultUVSTable))
        end
        if !iszero(selector.non_default_uvs_offset)
            seek(io, pos + selector.non_default_uvs_offset)
            push!(uvs_tables, read(io, NonDefaultUVSTable))
        end
    end
    seek(pos + length)
    UnicodeVariationSequences(format, length, num_var_selector_records, var_selectors, uvs_tables)
end

@serializable struct CharacterToGlyphIndexMappingTable
    version::UInt16
    num_tables::UInt16
    encoding_records::Vector{EncodingRecord} => num_tables
    subtables::Vector{CmapSubtable} << [read_at(io, CmapSubtable, rec.subtable_offset; start = __origin__) for rec in encoding_records]
end

function Base.show(io::IO, cmap::CharacterToGlyphIndexMappingTable)
    print(io, "CharacterToGlyphIndexMappingTable(", cmap.num_tables, " subtables")
    if !isempty(cmap.subtables)
        print(io, " with formats ")
        tables = copy(cmap.subtables)
        print(io, pop!(tables).format)
        for table in tables
            print(io, ", ", table.format)
        end
    end
    print(io, ')')
end

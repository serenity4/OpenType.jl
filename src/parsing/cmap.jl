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

abstract type CmapSubtable end

@serializable struct ByteEncodingTable <: CmapSubtable
    format::UInt16
    length::UInt16
    language::UInt16
    glyph_id_array::Vector{UInt8} => 256
end

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
@serializable struct HighByteMappingThroughTable <: CmapSubtable
    format::UInt16
    length::UInt16
    language::UInt16
    sub_header_keys::Vector{UInt16} => 256
    sub_headers::Vector{SubHeaderRecord} => maximum(sub_header_keys) ÷ 8
    glyph_id_array::Vector{UInt16} => maximum(sub_header_keys) ÷ 8
end

@serializable struct SegmentMappingToDeltaValues <: CmapSubtable
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
    glyph_id_array::Vector{UInt16} => segcount_x2 ÷ 2
end

@serializable struct TrimmedTableMapping <: CmapSubtable
    format::UInt16
    length::UInt16
    language::UInt16
    first_code::UInt16
    entry_count::UInt16
    glyph_id_array::Vector{UInt16} => entry_count
end

@serializable struct SequentialMapGroupRecord
    start_char_code::UInt32
    end_char_chode::UInt32
    start_glyph_id::UInt32
end

@serializable struct Mixed16And32BitCoverage <: CmapSubtable
    format::UInt16
    reserved::UInt16
    length::UInt32
    language::UInt32
    is_32::Vector{UInt8} => 8192
    num_groups::UInt32
    groups::SequentialMapGroupRecord
end

@serializable struct TrimmedArray <: CmapSubtable
    format::UInt16
    reserved::UInt16
    length::UInt32
    language::UInt32
    start_char_code::UInt32
    num_chars::UInt32
    glyph_id_array::Vector{UInt16} => num_chars
end

@serializable struct SegmentedCoverage <: CmapSubtable
    format::UInt16
    reserved::UInt16
    length::UInt32
    language::UInt32
    num_groups::UInt32
    groups::Vector{SequentialMapGroupRecord} => num_groups
end

@serializable struct ConstantMapGroupRecord
    start_char_code::UInt32
    end_char_chode::UInt32
    start_glyph_id::UInt32
end

@serializable struct ManyToOneRangeMappings <: CmapSubtable
    format::UInt16
    reserved::UInt16
    length::UInt32
    language::UInt32
    num_groups::UInt32
    groups::Vector{SequentialMapGroupRecord} => num_groups
end

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

struct UnicodeVariationSequences <: CmapSubtable
    format::UInt16
    length::UInt32
    num_var_selector_records::UInt32
    var_selectors::Vector{VariationSelectorRecord}
    uvs_tables::Vector{Union{DefaultUVSTable,NonDefaultUVSTable}}
end

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

struct CharacterToGlyphIndexMappingTable
    version::UInt16
    num_tables::UInt16
    encoding_records::Vector{EncodingRecord}
    subtables::Vector{Any}
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

function Base.read(io::IO, ::Type{CharacterToGlyphIndexMappingTable})
    pos = position(io)
    version, num_tables = read(io, UInt16), read(io, UInt16)
    encoding_records = [read(io, EncodingRecord) for _ in 1:num_tables]
    subtables = []
    farther_pos = pos
    for rec in encoding_records
        seek(io, pos + rec.subtable_offset)
        format = peek(io, UInt16)
        if format == 0
            push!(subtables, read(io, ByteEncodingTable))
        elseif format == 2
            push!(subtables, read(io, HighByteMappingThroughTable))
        elseif format == 4
            push!(subtables, read(io, SegmentMappingToDeltaValues))
        elseif format == 6
            push!(subtables, read(io, TrimmedTableMapping))
        elseif format == 8
            push!(subtables, read(io, Mixed16And32BitCoverage))
        elseif format == 10
            push!(subtables, read(io, TrimmedArray))
        elseif format == 12
            push!(subtables, read(io, SegmentedCoverage))
        elseif format == 13
            push!(subtables, read(io, ManyToOneRangeMappings))
        elseif format == 14
            push!(subtables, read(io, UnicodeVariationSequences))
        end
        farther_pos = max(farther_pos, position(io))
    end
    seek(io, farther_pos)
    CharacterToGlyphIndexMappingTable(version, num_tables, encoding_records, subtables)
end

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

function Base.parse(io::IO, table_mappings, ::Type{CharToGlyph})
    skip(io, 2)
    ntables = read(io, UInt16)
    records = map(1:ntables) do _
        EncodingRecord(
            PlatformID(read(io, UInt16)),
            [read(io, T) for T in fieldtypes(EncodingRecord)[2:3]]...
        )
    end
    d = Dict()
    foreach(records) do rec
        seek(io, table_mappings["cmap"].offset + rec.subtable_offset)
        format = read(io, UInt16)
        table = if format == 0
            skip(io, 4)
            ByteEncodingTable([read(io, UInt8) for _ in 1:256])
        elseif format == 12
            skip(io, 10)
            ngroups = read(io, UInt32)
            groups = map(1:ngroups) do i
                SequentialMapGroup(
                    read(io, UInt32):read(io, UInt32),
                    read(io, UInt32),
                )
            end
            SegmentedCoverage(groups)
        else
            return
        end
        d[format] = table
    end
    CharToGlyph(records, d)
end

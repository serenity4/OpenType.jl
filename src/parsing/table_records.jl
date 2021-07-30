struct TableRecord
    tag::String
    checksum::UInt32
    offset::UInt32
    length::UInt32
end

function Base.parse(::Type{TableRecord}, io::IO)
    tag = transcode(String, [read(io, UInt8) for _ in 1:4])
    TableRecord(tag, read(io, UInt32), read(io, UInt32), read(io, UInt32))
end

"""
Pad a table length so that it respects the four-byte
alignment requirements of the OpenType format.
"""
function padded_length(tr::TableRecord)
    4 * cld(tr.length, 4)
end

function checksum_head(io::IO, tr::TableRecord, adjustment)
    pos = position(io)
    sum = UInt32(0)
    seek(io, 0)
    i = 0
    while !eof(io)
        sum += read(io, UInt32)
    end
    seek(io, pos)
    sum -= adjustment
    0xb1b0afba - sum
end

function checksum(io::IO, tr::TableRecord)
    pos = position(io)
    sum = UInt32(0)
    seek(io, tr.offset)
    for _ in 1:cld(tr.length, 4)
        sum += read(io, UInt32)
    end
    seek(io, pos)
    sum
end

function validate(io::IO, table_records)
    foreach(table_records) do tr
        msg = "Invalid checksum for table $(tr.tag)"
        if tr.tag == "head"
            pos = position(io)
            seek(io, tr.offset + 8)
            adjustment = read(io, UInt32)
            seek(io, pos)
            checksum_head(io, tr, adjustment) == adjustment || error(msg)
        else
            checksum(io, tr) == tr.checksum || error(msg)
        end
    end
end

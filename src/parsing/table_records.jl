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

struct TableNavigationMap
    map::Dict{String,TableRecord}
end

TableNavigationMap(records::Vector{TableRecord}) = TableNavigationMap(Dict(rec.tag => rec for rec in records))

function validate(io::IO, nav::TableNavigationMap)
    foreach(values(nav.map)) do tr
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

Base.getindex(nav::TableNavigationMap, key) = nav.map[key]

function read_table(f, io::IO, record::TableRecord; length = record.length, offset = 0)
    seek(io, record.offset + offset)
    start = position(io)
    res = f(io)
    bytes_read = position(io) - start
    if bytes_read ≠ length
        error("Table \"$(record.tag)\" (restricted to $(record.offset + offset) → $(record.offset + offset + length)) was not read entirely. Bytes read: $bytes_read, expected: $length.")
    end
    res
end

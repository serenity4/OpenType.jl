struct TableRecord
    tag::String
    checksum::UInt32
    offset::UInt32
    length::UInt32
end

function Base.read(io::IO, ::Type{TableRecord})
    tag = transcode(String, [read(io, UInt8) for _ in 1:4])
    TableRecord(tag, read(io, UInt32), read(io, UInt32), read(io, UInt32))
end

Base.show(io::IO, tr::TableRecord) = print(io, "TableRecord(", '\"', tr.tag, '\"', ", checksum=", sprint(show, tr.checksum), ", offset=", tr.offset, ", length=", tr.length, ')')

function checksum_head(io::IO, tr::TableRecord, adjustment)
    pos = position(io)
    sum = sum = zero(UInt32)
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
    sum = zero(UInt32)
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
    for tr in values(nav.map)
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
Base.get(nav::TableNavigationMap, key, default) = get(nav.map, key, default)

read_table(f, io::IO, nav::TableNavigationMap, table::AbstractString; kwargs...) = read_table(f, io, get(nav, table, nothing); kwargs...)
read_table(::Any, ::IO, ::Nothing; kwargs...) = nothing

function read_table(f, io::IO, record::TableRecord; length = record.length, offset = 0)
    seek(io, record.offset + offset)
    start = position(io)
    res = f(io)
    bytes_read = position(io) - start
    if bytes_read ≠ length && record.tag ≠ "cmap"
        error("Table \"$(record.tag)\" (restricted to $(record.offset + offset) → $(record.offset + offset + length)) was not read entirely. Bytes read: $bytes_read, expected: $length.")
    end
    res
end

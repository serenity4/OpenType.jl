@serializable struct TableRecord
    tag::Tag
    checksum::UInt32
    offset::UInt32
    length::UInt32
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

const REQUIRED_TABLES = ["cmap", "head", "hhea", "hmtx", "maxp", "name", "OS/2", "post"]

function validate(io::IO, nav::TableNavigationMap)
    for tr in values(nav.map)
        msg = "Invalid checksum for table $(tr.tag)"
        if tr.tag == "head"
            pos = position(io)
            seek(io, tr.offset + 8)
            adjustment = read(io, UInt32)
            seek(io, pos)
            checksum_head(io, tr, adjustment) == adjustment || error_invalid_font(msg)
        else
            checksum(io, tr) == tr.checksum || error_invalid_font(msg)
        end
    end
end

Base.getindex(nav::TableNavigationMap, key) = nav.map[key]
Base.get(nav::TableNavigationMap, key, default) = get(nav.map, key, default)

function read_table(f, io::IO, nav::TableNavigationMap, table::AbstractString; kwargs...)
    record = get(nav, table, nothing)
    if isnothing(record)
        table in REQUIRED_TABLES && error_invalid_font(
            "Table \"$table\" not found. This table is mandatory as per
            the OpenType specification; the provided font is then invalid.")
        return nothing
    end
    read_table(f, io, record; kwargs...)
end

function read_table(f, io::IO, record::TableRecord; length = record.length, offset = 0)
    seek(io, record.offset + offset)
    start = position(io)
    @debug "Reading table $(record.tag) ($start → $(record.offset + offset + length))"
    res = f(io)
    bytes_read = position(io) - start
    bytes_read > length && error("Too many bytes read for table \"$(record.tag)\" (read $bytes_read, expected $length).")
    res
end

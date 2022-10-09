@serializable struct TableRecord
    tag::Tag
    checksum::UInt32
    offset::UInt32
    length::UInt32
end

Base.show(io::IO, tr::TableRecord) = print(io, "TableRecord(", '\"', tr.tag, '\"', ", checksum=", sprint(show, tr.checksum), ", offset=", tr.offset, ", length=", tr.length, ')')

"""
Verify the contents of the entire font.

!!! note
    Certain fonts may have invalid reference checksums yet remain valid for use, as existing tools sometimes allow for it and font
    publishers may not bother with providing correct checksums.

    Furthermore, this check does not use precomputed checksums but rather goes through the whole file and recompute a final checksum
    that is compared against a reference checksum. As a result, this is quite slow and this check might be made optional
    in the future.

    Ideally, we would simply sum up the checksums of every table, but attempts to do so have only led in invalid checksums.
"""
function verify_font_checksum(io::IO, head_tr::TableRecord)
    adjustment_pos = head_tr.offset + 8
    pos = position(io)
    sum = zero(UInt32)
    seekstart(io)
    master = nothing
    while !eof(io)
        if position(io) == adjustment_pos
            master = read(io, UInt32)
        else
            sum += read(io, UInt32)
        end
    end
    0xb1b0afba - sum == master || return InvalidFontException("Invalid font checksum: possible data corruption detected")
    nothing
end

function checksum(io::IO, tr::TableRecord)
    pos = position(io)
    sum = zero(UInt32)
    seek(io, tr.offset)
    # Special-case the 'head' table which contains a checksum inside of it.
    ishead = tr.tag == "head"
    for i in 1:cld(tr.length, 4)
        if i == 3 && ishead
            skip(io, 4)
            continue
        end
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

function verify_checksums(io::IO, nav::TableNavigationMap)
    head_tr = get(nav, "head", nothing)
    !isnothing(head_tr) || return InvalidFontException("'head' table required")

    ret = verify_font_checksum(io, head_tr)
    isnothing(ret) || return ret

    for tr in values(nav.map)
        seek(io, tr.offset)
        checksum(io, tr) == tr.checksum || return InvalidFontException("Invalid checksum for table $(tr.tag)")
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

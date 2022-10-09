"""
Read-only IO type which records what has been read by a user for debugging purposes.
"""
struct TracedIO{T} <: IO
  io::T
  ranges::Vector{UnitRange{UInt64}}
end
TracedIO(io::IO) = TracedIO(io, UnitRange{UInt64}[])

Base.isreadonly(io::TracedIO) = true

Base.seek(io::TracedIO, pos) = seek(io.io, pos)
Base.skip(io::TracedIO, offset) = skip(io.io, offset)

for f in (:mark, :unmark, :peek, :seekstart, :seekend, :position, :eof, :ismarked, :reset)
  @eval Base.$f(io::TracedIO) = $f(io.io)
end

for T in (:(Union{Type{Float16}, Type{Float32}, Type{Float64}, Type{Int128}, Type{Int16}, Type{Int32}, Type{Int64}, Type{UInt128}, Type{UInt16}, Type{UInt32}, Type{UInt64}}), :(Type{UInt8}), :(Type{<:Enum}))

  @eval function Base.read(io::TracedIO, T::$T)
    start = position(io)
    ret = read(io.io, T)
    push!(io.ranges, start:(position(io) - 1))
    ret
  end
end

function compact_ranges(ranges)
  holes = Int[]
  compacted = UnitRange{Int}[]
  overlap = Pair{UnitRange{Int}, Int}[]
  last = 0:0
  for range in sort(ranges, by = first)
    if range.start == last.stop
      last = last.start:range.stop
    else
      !iszero(last.stop) && push!(compacted, last)
      if range.start > last.stop
        push!(holes, length(compacted))
      elseif range.start < last.stop
        push!(overlap, range.start:last.stop)
      end
      last = range
    end
  end
  compacted
end

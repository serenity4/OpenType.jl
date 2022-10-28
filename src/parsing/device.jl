@enum DeltaFormat::UInt16 begin
  DELTA_FORMAT_LOCAL_2_BIT_DELTAS = 0x0001
  DELTA_FORMAT_LOCAL_4_BIT_DELTAS = 0x0002
  DELTA_FORMAT_LOCAL_8_BIT_DELTAS = 0x0003
  DELTA_FORMAT_VARIATION_INDEX = 0x8000
  DELTA_FORMAT_RESERVED = 0x7ffc
end

@serializable struct DeviceTable
  start_size::UInt16
  end_size::UInt16
  delta_format::DeltaFormat
  delta_value::Vector{UInt16} => cld(length(start_size:end_size) * 2^Int(delta_format), 16)
end

@serializable struct VariationIndexTable
  delta_set_outer_index::UInt16
  delta_set_inner_index::UInt16
  delta_format::DeltaFormat
end

function Base.read(io::IO, ::Type{Union{DeviceTable, VariationIndexTable}})
  format = read_at(io, DeltaFormat, 4)
  format == DELTA_FORMAT_VARIATION_INDEX && return read(io, VariationIndexTable)
  read(io, DeviceTable)
end

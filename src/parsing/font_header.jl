@bitmask_flag FontFlags::UInt16 begin
    FONT_BASELINE_Y_ZERO = 0x0000
    FONT_LSB_X_ZERO = 0x0001
    FONT_INSTR_SIZE_DEPENDENT = 0x0002
    FONT_FORCE_PPEM_INT = 0x0004
    FONT_INSTR_ALTER_AW = 0x0008
    FONT_RESERVED_BIT_1 = 0x0010
    FONT_RESERVED_BIT_2 = 0x0020
    FONT_RESERVED_BIT_3 = 0x0040
    FONT_RESERVED_BIT_4 = 0x0080
    FONT_RESERVED_BIT_5 = 0x0100
    FONT_RESERVED_BIT_6 = 0x0200
    FONT_LOSSLESS_DATA = 0x0400
    FONT_CONVERTED = 0x0800
    FONT_CLEARTYPE_OPTIMIZED = 0x1000
    FONT_LAST_RESORT = 0x2000
    FONT_RESERVED_BIT_7 = 0x4000
end

@serializable struct FontHeader
    major_version::UInt16
    minor_version::UInt16
    font_revision::Fixed
    checksum_adjustment::UInt32
    magic_number::UInt32
    flags::FontFlags
    units_per_em::UInt16
    created::LONGDATETIME
    modified::LONGDATETIME
    xmin::Int16
    ymin::Int16
    xmax::Int16
    ymax::Int16
    mac_style::UInt16
    lowest_rec_ppem::Int16
    font_direction_hint::Int16
    index_to_loc_format::Int16
    glyph_data_format::Int16
end

struct InvalidFontException <: Exception
    msg::AbstractString
end

Base.showerror(io::IO, err::InvalidFontException) = show(io, "InvalidFontException: ", err.msg)
error_invalid_font(msg::AbstractString) = throw(InvalidFontException(msg))

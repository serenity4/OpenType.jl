struct InvalidFontException <: Exception
    msg::AbstractString
end

Base.showerror(io::IO, err::InvalidFontException) = print(io, "Invalid font: ", err.msg)
error_invalid_font(msg::AbstractString) = throw(InvalidFontException(msg))

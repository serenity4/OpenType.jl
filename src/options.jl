Base.@kwdef struct FontOptions
  variable_coordinates::Vector{Any} = []
  apply_ligatures::Bool = true
  apply_kerning::Bool = true
end

Base.@kwdef struct TextOptions
  font_size::Float64 = 12
  line_spacing::Float64 = 1
  max_line_length::Float64 = 92
end

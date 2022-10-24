@enum Direction::UInt8 begin
  DIRECTION_LEFT_TO_RIGHT
  DIRECTION_RIGHT_TO_LEFT
  DIRECTION_TOP_TO_BOTTOM
  DIRECTION_BOTTOM_TO_TOP
end

struct ShapingOptions
  """
  OpenType or ISO-15924 script tag.
  """
  script::Tag{4}
  """
  ISO-639-1, ISO-639-3 or OpenType language tag.
  """
  language::Union{Tag{2},Tag{3},Tag{4}}
  direction::Direction
  features # TODO
end

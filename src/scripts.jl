struct ScriptEntry
  ranges::Vector{UnitRange{UInt32}}
  set::Set{UInt32}
end

function Base.in(codepoint::UInt32, script::ScriptEntry)
  in(codepoint, script.set) || any(in(codepoint, range) for range in script.ranges)
end

include("generated/scripts.jl")

function find_primary_script(codepoint::UInt32, recently_used::Vector{Tag4} = Tag4[])
  for script in recently_used
    entry = primary_scripts[script]
    in(codepoint, entry) && return script
  end
  for (script, entry) in primary_scripts
    in(script, recently_used) && continue
    in(codepoint, entry) && return script
  end
  error("Could not determine the primary script of character $(repr(chars[i]))")
end

function find_script(chars, i, recently_used::Vector{Tag4})
  codepoint = Base.codepoint(chars[i])
  script = find_primary_script(codepoint, recently_used)
  script == tag"zinh" && return i == firstindex(chars) ? script : find_script(chars, i - 1, recently_used)
  script ≠ tag"zyyy" && return script
  scripts = get(secondary_scripts, codepoint, nothing)
  if isnothing(scripts)
    i == firstindex(chars) && return script
    return find_script(chars, i - 1, recently_used)
  end
  length(scripts) == 1 && return @inbounds scripts[1]
  # If we have multiple choices, use surrounding chars to try to guess which one to take.
  if i ≠ firstindex(chars)
    prev = find_script(chars, i - 1, recently_used)
    in(prev, scripts) && return prev
  end
  if i ≠ lastindex(chars)
    # Look only for the primary script to avoid recursing forever if looking up surrounding characters is needed then.
    next = find_primary_script(chars[i + 1], recently_used)
    in(next, scripts) && return next
  end
  recent = findfirst(in(recently_used), scripts)
  !isnothing(recent) && return scripts[recent]
  # Just pick the first script if we really can't figure it out.
  scripts[1]
end

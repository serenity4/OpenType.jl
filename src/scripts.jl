struct ScriptEntry
  ranges::Vector{UnitRange{UInt32}}
  set::Set{UInt32}
end

function Base.in(codepoint::UInt32, script::ScriptEntry)
  in(codepoint, script.set) || any(in(codepoint, range) for range in script.ranges)
end

include("generated/scripts.jl")

function find_primary_script(codepoint::UInt32, recently_used::Vector{Tag4})
  for script in recently_used
    entry = primary_scripts[script]
    in(codepoint, entry) && return script
  end
  for (script, entry) in primary_scripts
    in(script, recently_used) && continue
    in(codepoint, entry) && return script
  end
end

function find_script(chars, i, recently_used::Vector{Tag4})
  codepoint = Base.codepoint(chars[i])
  script = find_primary_script(codepoint, recently_used)
  if script == tag"zyyy"
    scripts = secondary_scripts[codepoint]
    length(scripts) == 1 && return @inbounds scripts[1]
    # If we have multiple choices, use surrounding chars to try to guess which one to take.
    prev = find_script(chars, pick_previous_char(chars, i), recently_used)
    in(prev, scripts) && return prev
    next = find_script(chars, pick_next_char(chars, i), recently_used)
    in(next, scripts) && return next
    recent = findfirst(in(recently_used), scripts)
    !isnothing(recent) && return scripts[recent]
    # Just pick the first script if we really can't figure it out.
    return scripts[1]
  elseif script == tag"zinh"
    return find_script(chars, pick_neighboring_char(chars, i), recently_used)
  end
  error("Could not find script for codepoint $(repr(codepoint))")
end

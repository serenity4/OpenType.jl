using CSV
using DataFrames
using JuliaFormatter

# See https://www.unicode.org/reports/tr24/tr24-34.html
scripts_file = download("https://www.unicode.org/Public/UCD/latest/ucd/Scripts.txt")
script_extensions_file = download("https://www.unicode.org/Public/UCD/latest/ucd/ScriptExtensions.txt")
property_aliases = download("https://www.unicode.org/Public/UCD/latest/ucd/PropertyValueAliases.txt")

function scripts()
  data = ""
  for line in eachline(scripts_file)
    isempty(line) && continue
    startswith(line, '#') && continue
    line = split(line, '#')
    content, comment = length(line) == 1 ? (line[1], nothing) : line
    data *= content * '\n'
  end
  csv = CSV.File(IOBuffer(data); header = [:codepoints, :script])
  df = DataFrame(csv)
  transform(df, :codepoints => ByRow() do x
    contains(x, "..") ? range(parse.(UInt32, "0x" .* split(x, ".."))...) : parse(UInt32, "0x" * x)
  end => :codepoints)
end

function script_extensions()
  data = ""
  for line in eachline(script_extensions_file)
    isempty(line) && continue
    startswith(line, '#') && continue
    line = split(line, '#')
    content, comment = length(line) == 1 ? (line[1], nothing) : line
    data *= content * '\n'
  end
  csv = CSV.File(IOBuffer(data); header = [:codepoints, :scripts])
  df = DataFrame(csv)
  transform(df, :codepoints => ByRow() do x
    contains(x, "..") ? range(parse.(UInt32, "0x" .* split(x, ".."))...) : parse(UInt32, "0x" * x)
  end => :codepoints, :scripts => ByRow(x -> String.(filter!(!isempty, split(x, " ")))) => :scripts)
end

function scripts_iso15924()
  data = ""
  started = false
  for line in eachline(property_aliases)
    started |= line == "# Script (sc)"
    !started && continue
    isempty(line) && continue
    line == "# Script_Extensions (scx)" && break
    startswith(line, '#') && continue
    parts = split(line, ';')
    data *= join(strip.(parts[2:3]), ';') * '\n'
  end
  csv = CSV.File(IOBuffer(data); header = [:iso15924, :script], delim = ';')
  DataFrame(csv)
end

df = scripts()

n = sum(length, df.codepoints) # 149251
count(x -> isa(x, UInt32), df.codepoints) # 791
count(x -> isa(x, UnitRange{UInt32}), df.codepoints) # 1400
ranges = sort(filter(x -> isa(x, UnitRange{UInt32}), df.codepoints); by = length, rev = true)
count(>(1000) ∘ length, ranges) # 12
count(<(10) ∘ length, ranges) # 843
length.(ranges[1:5]) # 42720, 20992, 11172, 7473, 6592
gdf = groupby(df, :script) # 163 scripts
cdf = sort!(combine(gdf, :codepoints => (x -> sum(length, x)) => :count), :count, rev = true)
proportions = cumsum(cdf.count) ./ n
findlast(<(0.9), proportions) # 12
findfirst(>(0.99), proportions) # 119
count(<(1000), cdf.count) # 154
count(<(100), cdf.count) # 116
plot(proportions)
bar(cdf.count, ylim=(0,4000))

df = script_extensions() # 154
sum(length, df.codepoints) # 600
count(x -> isa(x, UInt32), df.codepoints) # 96
count(x -> isa(x, UnitRange{UInt32}), df.codepoints) # 58
ranges = sort(filter(x -> isa(x, UnitRange{UInt32}), df.codepoints); by = length, rev = true)
count(>(45) ∘ length, ranges) # 0
count(<(10) ∘ length, ranges) # 36
unique!(length.(df.scripts)) # 15 elements, from 1, 2, 3, 4 to 13, 14, 20, 21

sets = [1:3, 4:6, 8:9, 10:13, 14:15, 16:18, 19:23, 24:25]
@btime any(x -> 25 in x, $sets)
set = Set([collect.(sets)...;])
@btime 25 in $set

df = scripts_iso15924()

#=
- There is quite some overlap in terms of secondary scripts, codepoints may be assigned to a lot of secondary scripts at once.
- The number of codepoints assigned to secondary scripts is fairly low, we can allow ourselves to use sets for faster searches.
- For primary scripts, certain scripts do have a lot more codepoints than others. Han and Hangul lead with 98408 and 11739 codepoints, followed by Common (8301), Tangut (6914) and Latin (1481). More than 100 scripts over 163 have less than 100 codepoints.

- Checking a value in a set will be as efficient as checking a vector of ranges for less than 10 ranges in a worst-case scenario.
  If grouping large ranges at the start, and/or using a binary search, vectors of ranges may remain faster with more ranges.

Proposed design:
- Define a primary_scripts data structure, grouped by script, each script being associated with a set of codepoints and/or vectors of ranges, depending on distribution characteristics of individual scripts.
- Define a secondary_scripts data structure, which will be looked up only if codepoints have a 'Common' primary script. Define it as a dictionary that maps individual codepoints to vectors of scripts, where vectors are the same for the same vectors of scripts.
=#

#=
Accelerator ideas:
- If there are many scripts, just assign sets of characters to scripts. Could be expensive in terms of storage though, so ranges could be kept as such and a
  search would be performed on all ranges if no specific characters match the set.
- Look first for matches in scripts that were previously used. This requires a quick way to check whether a character is contained in a script.
- Instead of performing linear searches, use a binary search algorithm.

To determine the relevant script when several are applicable:
- If one of the scripts used for surrounding characters match one script in particular, use this one. If ambiguous, choose the script from the previous character.
- Otherwise, try to use application-provided script information to perform the selection.
- Otherwise, use the most recently used script among the applicable ones.
=#

primary_scripts_df = scripts()
secondary_scripts_df = script_extensions()
scripts_iso15924_df = scripts_iso15924()

secondary_scripts_variable(scripts) = Symbol("##", join(scripts, '_'))

grouped_secondary_scripts = combine(groupby(secondary_scripts_df, :scripts), :codepoints => (codepoints -> Ref(foldl((x, y) -> isa(y, UInt32) ? push!(x, y) : append!(x, y), codepoints; init = UInt32[]))) => :codepoints)

secondary_scripts_d = :(Dict($((:($codepoint => $(secondary_scripts_variable(scripts))) for (codepoints, scripts) in zip(grouped_secondary_scripts.codepoints, grouped_secondary_scripts.scripts) for codepoint in codepoints)...)))

target = joinpath(dirname(@__DIR__), "src", "generated", "scripts.jl")

scripts_iso15924_d = Dict(unicode => iso for (unicode, iso) in zip(scripts_iso15924_df.script, scripts_iso15924_df.iso15924))
as_tag(x) = Expr(:macrocall, Symbol("@tag4_str"), nothing, lowercasefirst(x))

open(target, "w") do io
  println(io, "# This file was generated by $(@__FILE__)")
  println(io)
  for scripts in grouped_secondary_scripts.scripts
    println(io, :(const $(secondary_scripts_variable(scripts)) = Tag4[$(as_tag.(scripts)...)]))
  end
  println(io, :(const secondary_scripts = $secondary_scripts_d))
end

format(target)

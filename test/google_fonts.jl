using OpenType, Test
using OpenType: OpenTypeData

fonts_repo = joinpath(@__DIR__, "google_fonts")

if !ispath(fonts_repo)
  @info "Getting fonts from Google Fonts, this may take a while..."
  run(`git clone https://github.com/google/fonts --depth=1 $fonts_repo`)
end

const FontFamily = String

google_font_files = Dict{FontFamily,Vector{String}}()

for font_family in readdir(joinpath(fonts_repo, "ofl"); join = true)
  ttf_files = filter(x -> last(splitext(x)) == ".ttf", readdir(font_family; join = true))
  google_font_files[basename(font_family)] = ttf_files
end

function load_google_fonts(google_font_files)
  google_font_data = Dict{FontFamily,Vector{OpenTypeData}}()
  failures = Dict{FontFamily,Vector{String}}()

  nfonts = sum(length, values(google_font_files))
  @info "Loading Google Fonts..."
  count = 0
  success = 0
  failed = 0
  for (font_family, font_files) in sort(collect(google_font_files); by = first)
    for font_file in font_files
      font_name = basename(font_file)
      print("\r", ' '^120)
      printstyled("\r $count/$nfonts ($failed failed) $font_name")
      try
        data = OpenTypeData(font_file)
        push!(get!(Vector{OpenTypeData}, google_font_data, font_family), data)
        success += 1
      catch
        println()
        @show font_family
        rethrow()
        failed += 1
        push!(get!(Vector{OpenTypeData}, failures, font_family), font_file)
      end
      count += 1
    end
  end

  google_font_data, failures
end

google_font_data, failures = load_google_fonts(google_font_files);

@test sum(length, values(google_font_data)) > 2500

data = OpenTypeData(first(google_font_files["aboreto"]));
font = OpenTypeFont(data);
font.gpos.scripts["latn"]
font.gpos.scripts["DFLT"]

file = first(google_font_files["alkalami"])
file = first(google_font_files["abrilfatface"])

data = OpenTypeData(file);

dst = joinpath(dirname(@__DIR__), "tmp", last(splitpath(file)))
cp(file, dst)
cd(dirname(dst)) do
  run(`ttx $dst`)
end

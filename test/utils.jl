font_file(filename) = joinpath(@__DIR__, "resources", filename * ".ttf")
load_font(filename) = OpenTypeData(font_file(filename))

# ENV["JULIA_DEBUG"] = "OpenType"

function dump_ttx(file)
  dst = joinpath(dirname(@__DIR__), "tmp", last(splitpath(file)))
  mkpath(dirname(dst))
  !isfile(dst) && cp(file, dst)
  cd(dirname(dst)) do
    run(`ttx $dst`)
  end
end

const google_fonts_repo = joinpath(@__DIR__, "google_fonts")
const FontFamily = String

function retrieve_google_font_files()
  if !ispath(google_fonts_repo)
    @info "Getting fonts from Google Fonts, this may take a while..."
    run(`git clone https://github.com/google/fonts --depth=1 $google_fonts_repo`)
  end

  google_font_files = Dict{FontFamily,Vector{String}}()

  for font_family in readdir(joinpath(google_fonts_repo, "ofl"); join=true)
    ttf_files = filter(x -> last(splitext(x)) == ".ttf", readdir(font_family; join=true))
    google_font_files[basename(font_family)] = ttf_files
  end

  google_font_files
end

google_font_files = retrieve_google_font_files();

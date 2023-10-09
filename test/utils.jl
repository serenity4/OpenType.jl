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
  if !isdir(google_fonts_repo)
    @info "Getting fonts from Google Fonts, this may take a while..."
    mkdir(google_fonts_repo)
    cd(google_fonts_repo) do
      run(`git init`)
      run(`git remote add origin https://github.com/google/fonts`)
      run(`git fetch --depth=1 origin 47a6c224b3e0287b2e48e3ffef8c9ce2ca4931f4`)
      run(`git checkout FETCH_HEAD`)
    end
  end

  google_font_files = Dict{FontFamily,Vector{String}}()

  for font_family in readdir(joinpath(google_fonts_repo, "ofl"); join=true)
    ttf_files = filter(x -> last(splitext(x)) == ".ttf", readdir(font_family; join=true))
    google_font_files[basename(font_family)] = ttf_files
  end

  google_font_files
end

google_font_files = retrieve_google_font_files();

using OpenType, Test
using OpenType: OpenTypeData

google_fonts_repo = joinpath(@__DIR__, "google_fonts")
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

function load_google_fonts(f, google_font_files; throw = false)
  nfonts = sum(length, values(google_font_files))
  @info "Loading Google Fonts..."
  count = 0
  success = 0
  failed = 0
  loaded = 0
  for (font_family, font_files) in sort(collect(google_font_files); by=first)
    for font_file in font_files
      font_name = basename(font_file)
      print("\r", ' '^120)
      printstyled("\r $count/$nfonts ($failed failed) $font_name")
      try
        data = OpenTypeData(font_file; verify_checksums = false)
        loaded += 1
        f(data)
        success += 1
      catch
        if throw
          print("\nFont family: ")
          printstyled(font_family * "\n\n"; color = :yellow)
          rethrow()
        else
          failed += 1
        end
      end
      count += 1
    end
  end

  success, failed, loaded
end

google_font_files = retrieve_google_font_files();

@testset "Google Fonts" begin
  # Make sure most of them load correctly, later we will check for actual contents.

   success, failed, loaded = load_google_fonts(identity, google_font_files)
   @test success ≥ 3009
end

# Uncomment to troubleshoot errors and increase coverage.
# load_google_fonts(identity, google_font_files; throw = true)

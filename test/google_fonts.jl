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

function load_google_fonts(f, google_font_files; throw = false, progress = true, start = 1, filter = Returns(true))
  nfonts = sum(length, values(google_font_files))
  @info "Loading Google Fonts..."
  count = 0
  success = 0
  failed = 0
  loaded = 0
  for (font_family, font_files) in sort(collect(google_font_files); by=first)
    for font_file in font_files
      count += 1
      start ≤ count || continue
      font_name = basename(font_file)
      if progress
        print("\r", ' '^120)
        printstyled("\r $count/$nfonts ($failed failed) $font_name")
      end
      try
        data = OpenTypeData(font_file; verify_checksums = false)
        loaded += 1
        filter(data) || continue
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
    end
  end
  progress && println()

  success, failed, loaded
end

google_font_files = retrieve_google_font_files();

@testset "Google Fonts" begin
  success, failed, loaded = load_google_fonts(identity, google_font_files; progress = false)
  @test success ≥ 3011
  success, failed, loaded = load_google_fonts(OpenTypeFont, google_font_files; progress = false, filter = x -> !isnothing(x.gpos))
  @test success ≥ 2643
end

# Uncomment to troubleshoot errors and increase coverage.
# load_google_fonts(identity, google_font_files; throw = true)
# load_google_fonts(identity, google_font_files; throw = false)
# success, failed, loaded = load_google_fonts(OpenTypeFont, google_font_files; progress = true, throw = false, start = 1, filter = x -> !isnothing(x.gpos))

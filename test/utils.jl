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

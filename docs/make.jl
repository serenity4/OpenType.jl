using Documenter, OpenType

makedocs(;
  modules = [OpenType],
  format = Documenter.HTML(prettyurls = true),
  pages = [
    "Home" => "index.md",
    "API" => "api.md",
  ],
  repo = "https://github.com/serenity4/OpenType.jl/blob/{commit}{path}#L{line}",
  sitename = "OpenType.jl",
  authors = "serenity4 <cedric.bel@hotmail.fr>",
)

deploydocs(
  repo = "github.com/serenity4/OpenType.jl.git",
)

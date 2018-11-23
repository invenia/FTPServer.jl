using Documenter, FTPLib

makedocs(;
    modules=[FTPLib],
    format=:html,
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/invenia/FTPLib.jl/blob/{commit}{path}#L{line}",
    sitename="FTPLib.jl",
    authors="Invenia Technical Computing Corporation",
    assets=[
        "assets/invenia.css",
        "assets/logo.png",
    ],
)

deploydocs(;
    repo="github.com/invenia/FTPLib.jl",
    target="build",
    julia="1.0",
    deps=nothing,
    make=nothing,
)

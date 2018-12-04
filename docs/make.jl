using Documenter, FTPServer

makedocs(;
    modules=[FTPServer],
    format=:html,
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/invenia/FTPServer.jl/blob/{commit}{path}#L{line}",
    sitename="FTPServer.jl",
    authors="Invenia Technical Computing Corporation",
    assets=[
        "assets/invenia.css",
        "assets/logo.png",
    ],
)

deploydocs(;
    repo="github.com/invenia/FTPServer.jl",
    target="build",
    julia="0.6",
    deps=nothing,
    make=nothing,
)

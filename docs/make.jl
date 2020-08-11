using Sequent
using Documenter

makedocs(;
    modules=[Sequent],
    authors="thautwarm <twshere@outlook.com> and contributors",
    repo="https://github.com/thautwarm/Sequent.jl/blob/{commit}{path}#L{line}",
    sitename="Sequent.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://thautwarm.github.io/Sequent.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/thautwarm/Sequent.jl",
)

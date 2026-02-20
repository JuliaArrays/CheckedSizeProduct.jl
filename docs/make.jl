using CheckedSizeProduct
using Documenter

DocMeta.setdocmeta!(CheckedSizeProduct, :DocTestSetup, :(using CheckedSizeProduct); recursive=true)

makedocs(;
    modules=[CheckedSizeProduct],
    authors="Neven Sajko <s@purelymail.com> and contributors",
    sitename="CheckedSizeProduct.jl",
    format=Documenter.HTML(;
        canonical="https://JuliaArrays.github.io/CheckedSizeProduct.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaArrays/CheckedSizeProduct.jl",
    devbranch="main",
)

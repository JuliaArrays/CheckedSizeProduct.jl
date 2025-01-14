# CheckedSizeProduct

[![Build Status](https://github.com/JuliaArrays/CheckedSizeProduct.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaArrays/CheckedSizeProduct.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Package version](https://juliahub.com/docs/General/CheckedSizeProduct/stable/version.svg)](https://juliahub.com/ui/Packages/General/CheckedSizeProduct)
[![Package dependencies](https://juliahub.com/docs/General/CheckedSizeProduct/stable/deps.svg)](https://juliahub.com/ui/Packages/General/CheckedSizeProduct?t=2)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/CheckedSizeProduct.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/CheckedSizeProduct.html)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

A small Julia package for safely calculating the length of an in-memory dense array given its dimensions.

The only public functionality is the exported function `checked_size_product`.

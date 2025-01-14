using CheckedSizeProduct
using Test
using Aqua

@testset "CheckedSizeProduct.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(CheckedSizeProduct)
    end
    # Write your tests here.
end

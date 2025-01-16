using CheckedSizeProduct
using Test
using Aqua: Aqua

function test_constant_folding(func, return_value)
    vec = code_typed(func, Tuple{})
    p = only(vec)
    code_info = first(p)
    code = try
        code_info.code
    catch
        nothing
    end
    @test repr(only(code)) == repr(:(return $return_value)) skip=(code isa Nothing)
end

@testset "CheckedSizeProduct.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(CheckedSizeProduct)
    end
    @testset "empty input" begin
        @test_throws Exception checked_size_product(())
    end
    @testset "singleton input" begin
        for T ∈ (Int8, Int16, Int32, Int64, Int128)
            for x ∈ 0:100
                y = T(x)
                @test y === checked_size_product((y,))
            end
        end
    end
    @testset "promotion" begin
        @test 10 === checked_size_product((Int8(2), 5))
        @test 10 === checked_size_product((2, Int8(5)))
        @test Int16(10) === checked_size_product((Int8(2), Int16(5)))
        @test Int16(10) === checked_size_product((Int16(2), Int8(5)))
    end
    @testset "input includes negative" begin
        for t ∈ (
            (-1,), (-1, 1), (1, -1), (0, -1), (-1, 0), (-1, -1),
            (-1, typemax(Int)), (typemax(Int), -1),
        )
            @test (checked_size_product(t)).any_is_negative
        end
    end
    @testset "input includes `typemax(T)`" begin
        m = typemax(Int)
        for t ∈ (
            (m,), (m, m), (1, m), (m, 1), (0, m), (m, 0), (-1, m), (m, -1),
        )
            @test (checked_size_product(t)).any_is_typemax
        end
    end
    @testset "overflows" begin
        m = typemax(Int) ÷ 13
        for t ∈ (
            (m, m), (15, m), (m, 15), (m, m, m), (1, m, m), (m, 1, m), (m, m, 1),
        )
            @test !(checked_size_product(t)).any_is_negative
            @test !(checked_size_product(t)).any_is_typemax
        end
    end
    @testset "overflows, but OK because of multiplication with zero" begin
        m = typemax(Int) ÷ 13
        for t ∈ (
            (m, m, 0), (m, 0, m), (0, m, m),
        )
            @test 0 === checked_size_product(t)
        end
    end
    @testset "exhaustive over small `Int8` values" begin
        ran = 0:4
        for x ∈ ran
            for y ∈ ran
                for z ∈ ran
                    ref = Int8(prod((x, y, z)))
                    a = Int8(x)
                    b = Int8(y)
                    c = Int8(z)
                    @test ref === checked_size_product((a, b, c))
                    @test ref === checked_size_product((true, a, b, c))
                    @test ref === checked_size_product((a, true, b, c))
                    @test ref === checked_size_product((a, b, true, c))
                    @test ref === checked_size_product((a, b, c, true))
                end
            end
        end
    end
    @testset "does it constant fold?" begin
        function func()
            t = ntuple(identity, Val{7}())
            checked_size_product(t)
        end
        if v"1.10" ≤ VERSION
            test_constant_folding(func, factorial(7))
        end
    end
end

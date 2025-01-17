using CheckedSizeProduct
using Test
using Aqua: Aqua

module ExampleInts
    export ExampleInt
    struct ExampleInt
        v::Int
        function ExampleInt(v::Int)
            new(v)
        end
    end
    function Base.iszero(n::ExampleInt)
        iszero(n.v)
    end
    function Base.typemax(n::ExampleInt)
        ExampleInt(typemax(n.v))
    end
    function Base.Checked.mul_with_overflow(l::ExampleInt, r::ExampleInt)
        (p, f) = Base.Checked.mul_with_overflow(l.v, r.v)
        (ExampleInt(p), f)
    end
    function Base.:(<)(l::ExampleInt, r::Int)
        l.v < r
    end
    function Base.promote_rule(::Type{Int}, ::Type{ExampleInt})
        ExampleInt
    end
    function Base.promote_rule(::Type{ExampleInt}, ::Type{Int})
        ExampleInt
    end
    function Base.promote_rule(::Type{Bool}, ::Type{ExampleInt})
        ExampleInt
    end
    function Base.promote_rule(::Type{ExampleInt}, ::Type{Bool})
        ExampleInt
    end
    function ExampleInt(n)
        ExampleInt(Int(n)::Int)
    end
    function Base.convert(::Type{ExampleInt}, n)
        ExampleInt(n)
    end
    function Base.convert(::Type{ExampleInt}, n::ExampleInt)
        n
    end
end

using .ExampleInts: ExampleInt

@testset "CheckedSizeProduct.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(CheckedSizeProduct)
    end
    @testset "empty input" begin
        @test_throws Exception checked_size_product(())
    end
    @testset "heterogeneous input" begin
        @test_throws Exception checked_size_product((Int32(2), Int64(3)))
    end
    @testset "singleton input" begin
        for T ∈ (Int8, Int16, Int32, Int64, Int128, ExampleInt)
            for x ∈ 0:100
                y = T(x)
                @test y === checked_size_product((y,))
            end
        end
    end
    @testset "input includes negative" begin
        for t ∈ (
            (-1,), (-1, 1), (1, -1), (0, -1), (-1, 0), (-1, -1),
            (-1, typemax(Int)), (typemax(Int), -1),
            (0, -4, -4), (-4, 1, 0), (-4, -4, 1),
        )
            @test (checked_size_product(t)).any_is_negative
            s = map(ExampleInt, t)
            @test (checked_size_product(s)).any_is_negative
        end
    end
    @testset "input includes `typemax(T)`" begin
        # Why is `typemax(T)` even disallowed:
        #
        # > Yes, I specifically wanted maxdim+1 to be representable, since
        # > otherwise other off-by-one math representations become much harder,
        # > and that makes boundschecking slower.
        #
        # https://github.com/JuliaLang/julia/pull/54255#pullrequestreview-2024051188
        m = typemax(Int)
        for t ∈ (
            (m,), (m, m), (1, m), (m, 1), (0, m), (m, 0), (-1, m), (m, -1),
        )
            @test (checked_size_product(t)).any_is_typemax
            s = map(ExampleInt, t)
            @test (checked_size_product(s)).any_is_typemax
        end
    end
    @testset "overflows" begin
        m = typemax(Int) ÷ 13
        b = (Int == Int64) ? 2^32 : 2^16
        for t ∈ (
            (m, m), (15, m), (m, 15), (m, m, m), (1, m, m), (m, 1, m), (m, m, 1),
            (b, b), (1, b, b),
        )
            @test !(checked_size_product(t)).any_is_negative
            @test !(checked_size_product(t)).any_is_typemax
            s = map(ExampleInt, t)
            @test !(checked_size_product(s)).any_is_negative
            @test !(checked_size_product(s)).any_is_typemax
        end
    end
    @testset "overflows, but OK because of multiplication with zero" begin
        m = typemax(Int) ÷ 13
        b = (Int == Int64) ? 2^32 : 2^16
        for t ∈ (
            (m, m, 0), (m, 0, m), (0, m, m),
            (0, b, b), (b, b, 0), (b, b, 0, b, b),
        )
            @test 0 === checked_size_product(t)
            s = map(ExampleInt, t)
            @test ExampleInt(0) === checked_size_product(s)
        end
    end
    @testset "exhaustive over small values" begin
        ran = 0:4
        for x ∈ ran
            for y ∈ ran
                for z ∈ ran
                    for T ∈ (Int8, Int16, Int32, Int64, Int128, ExampleInt)
                        ref = T(prod((x, y, z)))
                        o = T(1)
                        a = T(x)
                        b = T(y)
                        c = T(z)
                        @test ref === checked_size_product((a, b, c))
                        @test ref === checked_size_product((o, a, b, c))
                        @test ref === checked_size_product((a, o, b, c))
                        @test ref === checked_size_product((a, b, o, c))
                        @test ref === checked_size_product((a, b, c, o))
                    end
                end
            end
        end
    end
end

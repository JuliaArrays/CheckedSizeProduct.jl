using CheckedSizeProduct
using Test

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
    function Base.:(<)(l::ExampleInt, r::ExampleInt)
        l.v < r.v
    end
    function ExampleInt(n)
        if n isa ExampleInt
            return n
        end
        ExampleInt(Int(n)::Int)
    end
    function Base.convert(::Type{ExampleInt}, n)
        ExampleInt(n)
    end
end

using .ExampleInts: ExampleInt

const eltypes = (Int8, Int16, Int32, Int64, Int128, ExampleInt, BigInt)
const code_coverage_enabled = Base.JLOptions().code_coverage != 0

# The size tuple is a static parameter, so a constant for the compiler.
function constant_size_product(::Val{t}) where {t}
    Val(checked_size_product(t))
end

@testset "CheckedSizeProduct.jl" begin
    @testset "empty input" begin
        @test_throws MethodError checked_size_product(())
    end
    @testset "heterogeneous input" begin
        @test_throws MethodError checked_size_product((Int32(2), Int64(3)))
    end
    @testset "singleton input" begin
        for T ∈ eltypes
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
            @test nothing === checked_size_product(t)
            s = map(ExampleInt, t)
            @test nothing === checked_size_product(s)
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
            @test nothing === checked_size_product(t)
            s = map(ExampleInt, t)
            @test nothing === checked_size_product(s)
        end
    end
    @testset "overflows" begin
        m = typemax(Int) ÷ 13
        b = (Int == Int64) ? 2^32 : 2^16
        for t ∈ (
            (m, m), (15, m), (m, 15), (m, m, m), (1, m, m), (m, 1, m), (m, m, 1),
            (b, b), (1, b, b),
        )
            @test nothing === checked_size_product(t)
            s = map(ExampleInt, t)
            @test nothing === checked_size_product(s)
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
                    for T ∈ eltypes
                        ref = T(prod((x, y, z)))
                        o = T(1)
                        a = T(x)
                        b = T(y)
                        c = T(z)
                        @test ref == checked_size_product((a, b, c))::T
                        @test ref == checked_size_product((o, a, b, c))::T
                        @test ref == checked_size_product((a, o, b, c))::T
                        @test ref == checked_size_product((a, b, o, c))::T
                        @test ref == checked_size_product((a, b, c, o))::T
                    end
                end
            end
        end
    end
    @testset "long input" begin
        for n ∈ (8, 32, 64, 100)
            @test [Union{Nothing, Int}] == Base.return_types(checked_size_product, (NTuple{n, Int},))
            @test 1 === checked_size_product(ntuple(i -> 1, n))
            @test 0 === checked_size_product(ntuple(i -> (i == n) ? 0 : 1, n))
            @test nothing === checked_size_product(ntuple(i -> (i == n) ? -1 : 1, n))
            # `2^(Sys.WORD_SIZE - 1)` is not representable as an `Int`
            ref = (n ≤ Sys.WORD_SIZE - 2) ? 2^n : nothing
            @test ref === checked_size_product(ntuple(i -> 2, n))
            @test 0 === checked_size_product(ntuple(i -> (i == n) ? 0 : 2, n))
        end
    end
    if VERSION ≥ v"1.10"
        @testset "constant folding" begin
            @test [Val{60}] == Base.return_types(() -> Val(checked_size_product((3, 4, 5))), ())
            # For types wider than `Int` (e.g. `Int64` on 32-bit platforms), `Base` implements
            # `mul_with_overflow` in software, which may not be constant-folded.
            for T ∈ filter(T -> isbitstype(T) && sizeof(T) ≤ sizeof(Int), eltypes)
                m = typemax((T <: Integer) ? T : Int)
                inputs = (
                    (3, 4, 5), (0, -1), (-1, 3, 4), (3, 4, 0), (m, 1), (m ÷ 2, 3), (m ÷ 2, 3, 0),
                    map(n -> ntuple(i -> isodd(i) ? 1 : 2, n), (1, 2, 3, 4, 5, 6, 8, 16, 32))...,
                )
                for t ∈ inputs
                    s = map(T, t)
                    @test [Val{checked_size_product(s)}] == Base.return_types(constant_size_product, (Val{s},))
                end
            end
        end
    end
    if isdefined(Base, :infer_effects)
        @testset "effects" begin
            # Termination of the loops over tuples longer than 32 elements is proven only
            # from Julia v1.11.
            lengths = Tuple(1:32)
            if VERSION ≥ v"1.11"
                lengths = (lengths..., 33:250...)
            end
            # Arithmetic on `BigInt`s is never proven to terminate.
            for T ∈ filter(isbitstype, eltypes), n ∈ lengths
                effects = Base.infer_effects(checked_size_product, (NTuple{n, T},))
                @test Core.Compiler.is_terminates(effects)
                # Julia v1.8 does not prove consistency, required for constant folding.
                if VERSION ≥ v"1.9"
                    @test Core.Compiler.is_consistent(effects)
                    @test Core.Compiler.is_foldable(effects) skip = code_coverage_enabled
                end
            end
        end
    end
end

using Aqua: Aqua
@testset "Code quality (Aqua.jl)" begin
    Aqua.test_all(CheckedSizeProduct)
end

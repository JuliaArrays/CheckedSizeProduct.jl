module CheckedSizeProduct
    export checked_size_product

    """
        checked_size_product(size_tuple)

    In short; a safe product, suitable for computing, e.g., the value of
    `length(dense_array)` from the value of `size(dense_array)`. In case everything
    is as expected, return the value of the product of the elements of the given
    tuple. Otherwise, return `nothing`.

    In more detail; given `size_tuple`, a nonempty homogeneous tuple of `Integer`-likes:

    0. Give the name `T` to `eltype(size_tuple)` for the purposes of this doc string.

    1. The user must ensure `T` supports:

        * `Base.Checked.mul_with_overflow`
        * `iszero`
        * `typemax`
        * `<`
        * `==`

    2. Calculate the product. In case no element is negative, no element is `typemax(T)`
       and the product does not overflow, return the product. Otherwise return `nothing`.

    Throws if `isempty(size_tuple)` to avoid having to choose a return type arbitrarily.

    ### Usage examples in the REPL

    ```jldoctest
    julia> using CheckedSizeProduct

    julia> checked_size_product((3, 7))
    21

    julia> checked_size_product((3, -7))

    julia> checked_size_product((0, -7))

    julia> checked_size_product((0, 7))
    0

    julia> checked_size_product(())
    ERROR: MethodError: no method matching checked_size_product(::Tuple{})
    [...]
    ```
    """
    function checked_size_product end

    const NonemptyNTuple = Tuple{T, Vararg{T, N}} where {T, N}

    # The reductions over the tuple are recursive rather than loops, so that they're
    # unrolled already in the Julia IR: loops count heavily towards the inlining cost of
    # the callers, e.g. preventing inlining of functions which allocate arrays.

    function checked_dims_recursive(a, have_overflow::Bool, ::Tuple{})
        (a, have_overflow)
    end

    function checked_dims_recursive(a, have_overflow::Bool, t::Tuple)
        (m, o) = Base.Checked.mul_with_overflow(a, first(t))
        checked_dims_recursive(m, have_overflow | o, Base.tail(t))
    end

    function checked_dims(t::NonemptyNTuple)
        checked_dims_recursive(first(t), false, Base.tail(t))
    end

    function any_nonshortcircuiting(::Any, ::Tuple{})
        false
    end

    function any_nonshortcircuiting(f, t::Tuple)
        f(first(t)) | any_nonshortcircuiting(f, Base.tail(t))
    end

    function is_negative(x)
        x < typeof(x)(0)
    end

    function is_typemax(x)
        if x isa BigInt
            return false
        end
        x == typemax(x)
    end

    function is_negative_or_typemax(x)
        is_negative(x) | is_typemax(x)
    end

    function typeassert_bool(x::Bool)
        x
    end

    function checked_size_product(t::NonemptyNTuple)
        any_is_zero = any_nonshortcircuiting(typeassert_bool ∘ iszero, t)
        any_is_invalid = any_nonshortcircuiting(typeassert_bool ∘ is_negative_or_typemax, t)
        (product, have_overflow) = checked_dims(t)
        is_not_representable = have_overflow & !any_is_zero
        if any_is_invalid | is_not_representable
            nothing
        else
            product
        end
    end
end
